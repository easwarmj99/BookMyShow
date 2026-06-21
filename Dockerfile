# Dockerfile — Book-My-Show React.js Multi-Stage Production Build
# Place this file at the ROOT of the repository (same level as bookmyshow-app/)
# nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
# STAGE 1: Install dependencies
# nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
FROM node:18-alpine AS deps
LABEL maintainer="devops@bookmyshow.com"
WORKDIR /app
# Copy package files first — Docker layer cache optimization
# If package.json does not change, this layer is reused
COPY bookmyshow-app/package*.json ./
# Install ONLY production dependencies
RUN npm ci --only=production --silent && npm cache clean --force
# nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
# STAGE 2: Build the React application
# nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
FROM node:18-alpine AS builder
WORKDIR /app
# Copy package files and install ALL deps (including dev for build)
COPY bookmyshow-app/package*.json ./
RUN npm ci --silent
# Copy the React source code
COPY bookmyshow-app/ .
# Build the production React bundle
# Output goes to /app/build/
RUN npm run build
# nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
# STAGE 3: Production — serve with nginx
# This is the FINAL image — only ~25-35 MB
# No Node.js, no npm, no source code in final image
# nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
FROM nginx:1.25-alpine AS production
# Add OCI standard labels for traceability
LABEL org.opencontainers.image.title="Book-My-Show"
LABEL org.opencontainers.image.description="Movie ticket booking React app"
LABEL org.opencontainers.image.source="https://github.com/vijay3639/Book-My-Show"
# Remove default nginx welcome page
RUN rm -rf /usr/share/nginx/html/*
# Create non-root user and group for security
RUN addgroup -g 1001 -S appgroup && \
adduser -u 1001 -S appuser -G appgroup
# Copy the production React build from builder stage
COPY --from=builder /app/build /usr/share/nginx/html
# Copy custom nginx configuration (created in step 3.4)
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Fix permissions so non-root nginx can run
RUN chown -R appuser:appgroup /usr/share/nginx/html && \
chown -R appuser:appgroup /var/cache/nginx && \
chown -R appuser:appgroup /var/log/nginx && \
touch /var/run/nginx.pid && \
chown appuser:appgroup /var/run/nginx.pid
# Switch to non-root user
USER appuser
EXPOSE 80
# Health check — Kubernetes uses this for probes
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
CMD wget -qO- http://localhost:80/ || exit 1
# Run nginx in foreground (daemon off required for containers)
CMD ["nginx", "-g", "daemon off;"]
