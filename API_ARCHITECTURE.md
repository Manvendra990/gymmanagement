# Power Cave API Architecture

## Flutter
- `lib/api/api_config.dart` - base URL and timeout
- `lib/api/api_endpoints.dart` - centralized endpoint definitions
- `lib/api/api_exception.dart` - normalized API/network errors
- `lib/api/api_client.dart` - HTTP/JWT/multipart/logging layer
- `lib/db/app_db.dart` - data facade routing online accounts to the API and offline accounts to SQLite
- `lib/dblocal/offline_store.dart` - on-device SQLite business-data store

Accounts returned by the API include `type: "online"` or `type: "offline"`.
Online accounts use the API for gym data. Offline accounts use only the local
SQLite database after sign-in; no gym-data API calls are made for that session.
The app also includes an offline demo login: `demo@gmail.com` / `123456`.
Its SQLite database starts empty and is not synchronized to the server.

The signup API accepts an optional `type` field (`online` or `offline`); when
omitted it defaults to `online`. The mobile app intentionally has no registration
screen. Account creation requires the `x-super-admin-key` header, configured
using `SUPER_ADMIN_KEY` in the backend environment; never ship this key in the
mobile app.

### Request logs
Run Flutter with `flutter run`. Every request prints:
`[API] --> GET http://.../api/v1/members`
`[API] <-- GET /members [200] 42ms`

## NestJS
- Feature modules: `auth`, `members`, `finance`, `settings`, `checkins`
- `prisma` - MySQL access
- `common/request-logger.middleware.ts` - incoming API logs

Run `npm run start:dev`; each hit prints method, URL, HTTP status and duration.

## Empty member behavior
`GET /api/v1/members` returning `[]` renders the existing Members empty state: `No members yet...`. It never injects demo members.
