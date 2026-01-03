# Build stage - compile Flutter web app
FROM --platform=linux/amd64 ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY . .

RUN flutter config --no-analytics
RUN git config --global --add safe.directory /sdks/flutter
RUN flutter pub get
RUN flutter build web --release

# Production stage - serve static files with nginx
FROM --platform=linux/amd64 nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf.template

EXPOSE 80

CMD ["/bin/sh", "-c", "export PORT=${PORT:-80} && envsubst '$PORT' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && nginx -g 'daemon off;'"]
