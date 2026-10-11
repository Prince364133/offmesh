import type { FastifyPluginAsync } from 'fastify';
import { authService } from '../auth/auth.service.js';
import { billingService } from './billing.service.js';

export const billingRoutes: FastifyPluginAsync = async (app) => {
  // Authentication middleware
  const authenticate = async (req: any, reply: any) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return reply.code(401).send({ error: 'Missing or malformed Authorization header' });
    }
    const token = authHeader.substring(7);
    const decoded = authService.verifyToken(token);
    if (!decoded) {
      return reply.code(401).send({ error: 'Invalid or expired session token' });
    }
    req.user = decoded;
  };

  /**
   * GET /api/v1/billing/status
   * Check 3-day free trial or $5/month active subscription status.
   */
  app.get('/status', {
    preHandler: [authenticate],
    schema: {
      tags: ['Billing'],
      description: 'Check whether the user has active chat access (3-day free trial or $5/month plan)',
      response: {
        200: {
          type: 'object',
          properties: {
            userId: { type: 'string' },
            status: { type: 'string', enum: ['TRIAL', 'ACTIVE', 'EXPIRED', 'CANCELLED'] },
            plan: { type: 'string' },
            priceUsd: { type: 'number' },
            isTrialActive: { type: 'boolean' },
            isSubscribed: { type: 'boolean' },
            hasChatAccess: { type: 'boolean' },
            trialDaysRemaining: { type: 'number' },
            trialEndsAt: { type: 'string' },
            subscriptionEndsAt: { type: ['string', 'null'] },
          },
        },
      },
    },
  }, async (req: any) => {
    return billingService.getSubscriptionStatus(req.user.sub);
  });

  /**
   * POST /api/v1/billing/subscribe
   * Activate or renew the $5/month Haven Sanctuary subscription.
   */
  app.post('/subscribe', {
    preHandler: [authenticate],
    schema: {
      tags: ['Billing'],
      description: 'Subscribe to the $5/month Haven Sanctuary plan to unlock unlimited chat access',
      body: {
        type: 'object',
        properties: {
          paymentProvider: { type: 'string' },
        },
      },
      response: {
        200: {
          type: 'object',
          properties: {
            success: { type: 'boolean' },
            subscription: {
              type: 'object',
              properties: {
                userId: { type: 'string' },
                status: { type: 'string' },
                plan: { type: 'string' },
                priceUsd: { type: 'number' },
                isSubscribed: { type: 'boolean' },
                hasChatAccess: { type: 'boolean' },
                subscriptionEndsAt: { type: ['string', 'null'] },
              },
            },
          },
        },
      },
    },
  }, async (req: any) => {
    const provider = req.body?.paymentProvider || 'STRIPE_GOOGLE_PLAY';
    const sub = await billingService.subscribeMonthly(req.user.sub, provider);
    return {
      success: true,
      subscription: sub,
    };
  });

  /**
   * POST /api/v1/billing/checkout-session
  /**
   * POST /api/v1/billing/checkout-session
   * Create a 180pay or Stripe Checkout session for the $5/month Haven Sanctuary plan.
   */
  app.post('/checkout-session', {
    preHandler: [authenticate],
    schema: {
      tags: ['Billing'],
      description: 'Create a Checkout Session for $5/month Haven Sanctuary membership via 180pay or Stripe',
    },
  }, async (req: any, reply) => {
    const userId = req.user.sub;
    const provider = req.body?.provider || process.env.PAYMENT_PROVIDER || '180pay';
    const appUrl = process.env.APP_URL || 'http://localhost:3000';

    // 1. Primary: 180pay Provider
    if (provider === '180pay') {
      const session = await billingService.create180PayCheckoutSession(userId);
      return {
        sessionId: session.sessionId,
        url: session.checkoutUrl,
        provider: '180PAY',
        amount: session.amount,
        currency: session.currency,
      };
    }

    // 2. Secondary: Stripe Provider
    const stripeKey = process.env.STRIPE_SECRET_KEY;
    const priceId = process.env.STRIPE_PRICE_ID_MONTHLY_5 || 'price_haven_monthly_5usd';

    if (!stripeKey || stripeKey.startsWith('sk_test_mock')) {
      return {
        sessionId: `cs_mock_${Date.now()}`,
        url: `${appUrl}/billing/success?mock=true&userId=${userId}`,
        provider: 'MOCK',
      };
    }

    try {
      const res = await fetch('https://api.stripe.com/v1/checkout/sessions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${stripeKey}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          'success_url': `${appUrl}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
          'cancel_url': `${appUrl}/billing/cancel`,
          'mode': 'subscription',
          'client_reference_id': userId,
          'line_items[0][price]': priceId,
          'line_items[0][quantity]': '1',
          'metadata[userId]': userId,
        }).toString(),
      });

      const session = await res.json() as any;
      if (session.error) {
        return reply.status(400).send({ error: session.error.message });
      }

      return {
        sessionId: session.id,
        url: session.url,
        provider: 'STRIPE',
      };
    } catch (e: any) {
      return reply.status(500).send({ error: e.message || 'Failed to create Stripe checkout session' });
    }
  });

  /**
   * POST /api/v1/billing/webhook/180pay
   * 180pay Webhook receiver for automated subscription activation and cancellation.
   */
  app.post('/webhook/180pay', {
    schema: {
      tags: ['Billing'],
      description: '180pay webhook receiver for subscription events',
    },
  }, async (req: any, reply) => {
    const event = req.body;
    if (!event) {
      return reply.status(400).send({ error: 'Missing webhook payload' });
    }

    const signature = (req.headers['x-180-signature'] || req.headers['x-signature'] || '') as string;
    const rawBody = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);

    try {
      const result = await billingService.handle180PayWebhook({
        payload: event,
        signature,
        rawBody,
      });
      return reply.status(200).send({ received: true, ...result });
    } catch (e: any) {
      return reply.status(500).send({ error: e.message || '180pay webhook processing failed' });
    }
  });

  /**
   * POST /api/v1/billing/webhook/stripe
   * Stripe Webhook receiver for automated subscription activation and cancellation.
   */
  app.post('/webhook/stripe', {
    schema: {
      tags: ['Billing'],
      description: 'Stripe webhook receiver for handling subscription lifecycle events',
    },
  }, async (req: any, reply) => {
    const event = req.body;
    if (!event || !event.type) {
      return reply.status(400).send({ error: 'Malformed webhook event payload' });
    }

    try {
      const result = await billingService.handleStripeWebhook(event);
      return reply.status(200).send({ received: true, ...result });
    } catch (e: any) {
      return reply.status(500).send({ error: e.message || 'Webhook processing failed' });
    }
  });
};
