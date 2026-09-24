# Multi-stage production build for OffMesh Modular Monolith Backend
# Stage 1: Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# Install build dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy application source
COPY tsconfig.json ./
COPY src/ ./src/

# Compile TypeScript to JavaScript
RUN npm run build

# Prune development dependencies
RUN npm prune --production

# Stage 2: Production runtime stage
FROM node:22-alpine AS runner

WORKDIR /app

# Install curl/wget for container health checking
RUN apk --no-cache add wget

# Security: run as non-root user
RUN addgroup -S -g 1001 offmesh && \
    adduser -S -u 1001 -G offmesh offmesh

# Copy production artifacts and dependencies
COPY --from=builder --chown=offmesh:offmesh /app/node_modules ./node_modules
COPY --from=builder --chown=offmesh:offmesh /app/dist ./dist
COPY --from=builder --chown=offmesh:offmesh /app/package.json ./package.json

USER offmesh

ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0

EXPOSE 3000

HEALTHCHECK --interval=20s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "dist/index.js"]
