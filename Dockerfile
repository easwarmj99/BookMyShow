# ===================================================================
# Dockerfile - BookMyShow React Application
# Multi-stage build: Node (build) -> Nginx (serve)
# ===================================================================
# ---------- Stage 1: Build ----------
FROM node:16-alpine AS build
WORKDIR /app
# Install dependencies first (better layer caching)
COPY bookmyshow-app/package*.json ./
RUN npm install --legacy-peer-deps
# Copy source and build static assets
COPY bookmyshow-app/ ./
ENV NODE_OPTIONS=--openssl-legacy-provider
RUN npm run build
# ---------- Stage 2: Serve ----------
FROM nginx:1.25-alpine
# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*
# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Copy built React app from the build stage
COPY --from=build /app/build /usr/share/nginx/html
# Run as non-root for security (Trivy/SonarQube friendlier image)
RUN addgroup -g 1001 -S appgroup && \
adduser -u 1001 -S appuser -G appgroup && \
chown -R appuser:appgroup /usr/share/nginx/html && \
chown -R appuser:appgroup /var/cache/nginx && \
chown -R appuser:appgroup /var/log/nginx && \
chown -R appuser:appgroup /etc/nginx/conf.d && \
touch /var/run/nginx.pid && \
chown -R appuser:appgroup /var/run/nginx.pid
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
CMD wget -qO- http://127.0.0.1:8080/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
