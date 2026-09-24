# OffMesh --- UI/UX Design Principles

**Document type:** Product UX principles\
**Product:** OffMesh --- offline-first, peer-to-peer and server-assisted
messaging\
**Version:** 1.0\
**Visual reference:** Minimal monochrome interface supplied by the
product owner

## 1. Product experience goal

OffMesh helps people communicate when internet connectivity is
unreliable or unavailable. The interface must make the messaging
experience feel familiar while clearly communicating when messages are
nearby, queued, relayed, uploaded, delivered, cancelled, or expired.

The UI should never imply that a message has reached its recipient when
the app only stored or forwarded it.

## 2. Core principles

### 2.1 Clarity over cleverness

Use familiar messaging patterns, plain language, recognizable icons, and
predictable navigation. Avoid technical jargon in everyday user-facing
screens. Put protocol details in expandable diagnostics or connection
details.

### 2.2 Honest delivery feedback

Represent each stage accurately: - **Sending / Queued:** The message is
saved locally and waiting for a route. - **Forwarding:** A permitted
relay has accepted a copy. - **Uploaded:** The server has stored the
message; this does not mean the recipient received it. - **Delivered:**
The recipient device has confirmed receipt. - **Failed / Expired /
Cancelled:** Explain what happened and, where possible, what the user
can do next.

Never use a generic "Sent" indicator if it could be interpreted as
"Delivered" while the message is only queued.

### 2.3 Offline-first, not offline-only

Make core local functions understandable without internet. Show whether
the device is connected to nearby peers, whether it has internet access,
and whether server synchronization is pending. Do not make the user
guess which network path is currently available.

### 2.4 Consent and user control

Nearby discovery, relay participation, contact sharing, and location
sharing must be understandable and controllable. Explain why a
permission is requested before the operating-system prompt. Location is
optional and must not be silently shared.

### 2.5 Privacy by default

Keep message content private from relay devices. Use authenticated,
encrypted communication. Minimize exposed identity data and avoid
showing message previews to unrelated nearby users. Provide clear
controls for blocking, reporting, and managing relay participation.

### 2.6 Predictable behavior

Use consistent layouts, button placement, status language, gestures, and
navigation. A user should be able to predict what tapping an action will
do, especially for sending, cancelling, deleting, and sharing.

### 2.7 Progressive disclosure

Show essential status first. Place advanced information---message ID,
hop count, relay path, sync cursor, server receipt, and troubleshooting
details---behind "Details" or "Advanced" views.

### 2.8 Resilient interaction

Assume connections may disappear during discovery, pairing, transfer, or
synchronization. Preserve drafts and queued messages. Show progress and
allow safe retry/resume without duplicating the logical message.

### 2.9 Accessible by design

Support readable type, sufficient contrast, scalable text, screen
readers, touch targets, reduced motion, and non-color status cues. Do
not rely on color alone to distinguish delivered, pending, cancelled, or
failed states.

### 2.10 Calm, restrained visual design

The selected monochrome theme uses a white/light surface, dark text,
subtle gray separators, and a restrained black primary action. Keep the
interface quiet and content-focused rather than decorative.

## 3. Information architecture

Recommended bottom navigation: 1. **Chats** --- conversation list and
chat threads. 2. **People** --- saved contacts, contact requests, QR
contact card. 3. **Nearby** --- nearby devices, discovery status, and
connection controls. 4. **Settings** --- account, privacy, connectivity,
relay controls, storage, and support.

The home/Chats screen should prioritize conversations and actionable
delivery states. Nearby discovery should be available without making the
app feel like a device-scanning utility.

## 4. Interaction principles by workflow

### Onboarding and identity

-   Explain the value proposition in one short screen.
-   Request permissions only when a feature needs them.
-   Offer a clear "Not now" path for optional permissions.
-   Explain that nearby discovery requires supported radios and OS
    permissions; the app cannot silently turn on Bluetooth or Wi-Fi when
    the operating system disallows it.
-   Make identity setup simple, with optional profile image and a
    human-readable display name.

### Nearby discovery and connection

-   Distinguish **Nearby**, **Connecting**, **Connected**, and
    **Disconnected**.
-   Show approximate proximity only when the platform provides a
    reliable basis; avoid false precision.
-   Require user confirmation for consequential contact or trust
    actions.
-   Provide a visible stop-discovery control and an explanation of relay
    behavior.

### Messaging

-   Preserve unsent text if the app closes or connectivity changes.
-   Show the message's current delivery state near the message bubble.
-   Make cancellation available only where the product's policy permits
    it, and explain that remote copies may not be retractable until
    devices reconnect.
-   Avoid duplicate bubbles when the same message arrives over local and
    server routes.

### Sync and forwarding

-   Use a clear progress list: exchanging summaries, syncing status
    updates, checking pending messages, transferring eligible messages,
    and finishing.
-   If interrupted, show "Paused" or "Will resume when connected," not a
    misleading success state.
-   Do not expose other users' message content or contact graph in a
    peer's ordinary UI.

### Location sharing

-   Treat live location as a separate, explicit action.
-   Show the recipient, scope, and duration before sharing.
-   Provide a stop-sharing action and a visible active-sharing
    indicator.
-   Explain that GPS can determine a location without internet in
    supported conditions, but transmitting it still requires a
    communication path.

## 5. Status language and microcopy

Use consistent, plain-language labels:

  -----------------------------------------------------------------------
  Status                              Suggested copy
  ----------------------------------- -----------------------------------
  Local queue                         "Waiting for a connection"

  Relay accepted                      "Being carried by nearby devices"

  Server stored                       "Stored on server --- waiting for
                                      recipient"

  Delivered                           "Delivered"

  Cancellation requested              "Cancellation requested"

  Cancelled                           "Forwarding stopped"

  Expired                             "Expired before delivery"

  Sync interrupted                    "Sync paused. It will resume when a
                                      connection is available."

  No route available                  "No route available yet. Keep
                                      OffMesh available to continue
                                      trying."
  -----------------------------------------------------------------------

Avoid promising guaranteed delivery or a delivery time.

## 6. Accessibility and usability requirements

-   Meet WCAG 2.2 AA contrast targets where applicable.
-   Body text should remain comfortably readable at the user's system
    text size.
-   Provide touch targets around 44--48 dp where practical.
-   Support TalkBack and meaningful accessibility labels.
-   Provide icons plus text for critical message states.
-   Do not communicate status through color alone.
-   Respect system font scaling and reduced-motion settings.
-   Keep forms short and errors adjacent to the affected field.

## 7. UX quality checks

Before release, test: - First-time onboarding with permissions denied. -
Discovery with Bluetooth/Wi-Fi disabled or unavailable. - Two nearby
devices with no internet. - Message queued for a distant recipient. -
Relay accepts a message, then loses connectivity. - Duplicate arrival
through multiple relays and the server. - Recipient receives the message
while stale copies remain in the network. - Cancellation arrives before
and after a relay receives the payload. - Expired messages and
interrupted sync. - Large text, screen reader, low battery, and
background restrictions.

## 8. Product trust rule

**The interface must describe what the system knows, not what the user
hopes has happened.** Delivery, cancellation, and synchronization claims
must be backed by the corresponding authenticated status.
