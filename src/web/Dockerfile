# Stage 1: Build the Angular app
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Serve with NGINX (unprivileged)
FROM nginxinc/nginx-unprivileged:alpine
COPY --from=build /app/dist/web/browser /usr/share/nginx/html
COPY <<'EOF' /etc/nginx/conf.d/default.conf
server {
    listen 8080;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Disable server version exposure
    server_tokens off;
}
EOF
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]