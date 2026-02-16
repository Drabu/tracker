# Frontend (Flutter)

## Stack
- Flutter (Dart 3.x), web build via Nginx in Docker

## Key paths
- lib/ (app code)
- assets/sounds/ (audio assets)
- web/ (web-specific assets)

## Commands
```bash
flutter pub get
flutter run
flutter test
flutter build web --release
```

## Docker
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t drabuburhan/frontend:dev --push .
```
