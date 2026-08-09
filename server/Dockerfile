# ---- Build stage ----
FROM node:20-slim AS build
WORKDIR /app

# better-sqlite3 compiles a native addon — needs build toolchain + python.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json* ./
RUN npm install

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Prune to production dependencies for the runtime image.
RUN npm prune --omit=dev

# ---- Runtime stage ----
FROM node:20-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

# Run as the non-root `node` user shipped in the base image.
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/package.json ./package.json

# Data dir for the SQLite file (mount a volume here in production).
RUN mkdir -p /app/data && chown node:node /app/data
USER node

EXPOSE 8080
CMD ["node", "dist/index.js"]
