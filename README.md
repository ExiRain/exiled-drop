# Exiled Drop

> Your messages, your server, your rules.

Self-hosted cross-platform messenger for family and friends. Run it on your notebook, a Raspberry Pi, or the cloud.

## MVP Features (v0.1.0)

- **1:1 Chat** — Real-time text messaging via WebSocket
- **Voice & Video Calls** — WebRTC peer-to-peer with TURN fallback
- **Auth** — JWT-based registration and login
- **Self-Hosted** — Single `docker-compose up` starts everything

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Java 21, Spring Boot 3.x |
| Database | PostgreSQL 16 |
| Real-time | WebSocket (raw JSON) |
| Calls | WebRTC + coturn (STUN/TURN) |
| Frontend | Flutter 3.x (Android, Web) |
| Deploy | Docker Compose |

## Quick Start

### Prerequisites

- **Java 21+** — `java -version` must show 21.x ([SDKMAN](https://sdkman.io/) recommended)
- **Docker & Docker Compose** — for PostgreSQL + TURN server
- **Flutter 3.x** — for frontend development (needed later)

### First-Time Setup

```bash
./scripts/check-prereqs.sh      # 1. verify tools installed
./scripts/init-project.sh       # 2. generate gradle wrapper, local config
./scripts/start-infra.sh        # 3. start PostgreSQL + coturn
./scripts/start-backend.sh      # 4. run the API
./scripts/seed-test-users.sh    # 5. create alice & bob test accounts
```

> **See [`scripts/INITREADME.md`](scripts/INITREADME.md) for detailed docs on every script, environment variables, and troubleshooting.**

### Daily Development

```bash
./scripts/start-infra.sh        # if Docker containers aren't running
./scripts/start-backend.sh      # start the API
```

### Shut Down

```bash
./scripts/stop-all.sh           # stop containers, keep data
./scripts/stop-all.sh --clean   # stop containers + wipe database
```

This starts:
- **API** at `http://localhost:8080`
- **PostgreSQL** at `localhost:5432`
- **TURN server** at `localhost:3478`

### Manual Setup (without scripts)

```bash
# Start just the database
cd docker
docker-compose up -d postgres coturn

# Run Spring Boot locally
cd ../backend
./gradlew bootRun
```

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register a new account |
| POST | `/api/auth/login` | Login, get JWT tokens |
| POST | `/api/auth/refresh` | Refresh access token |
| GET | `/api/users/me` | Current user profile |
| GET | `/api/users/search?q=` | Search users by username |
| GET | `/api/conversations` | List conversations |
| POST | `/api/conversations` | Create conversation |
| GET | `/api/conversations/{id}/messages` | Message history (paginated) |

### WebSocket

Connect to `ws://localhost:8080/ws?token=<JWT>` for real-time messaging and call signaling.

## Project Structure

```
exiled-drop/
├── backend/          # Java Spring Boot
│   └── src/main/java/com/exileddrop/
│       ├── auth/     # Registration, login, JWT
│       ├── user/     # Profiles, search
│       ├── chat/     # Conversations, messages
│       ├── ws/       # WebSocket handler, presence
│       ├── call/     # WebRTC signaling (via WS)
│       └── config/   # Security, CORS, exceptions
├── frontend/         # Flutter app (coming soon)
├── docker/           # Compose + Dockerfiles
├── docs/             # Documentation
└── scripts/          # Build & deploy scripts
```

## Roadmap

- [x] Project setup & auth
- [x] Real-time 1:1 chat
- [ ] Voice & video calls (WebRTC)
- [ ] Flutter app
- [ ] Group conversations
- [ ] Shared to-do lists
- [ ] File uploads
- [ ] Push notifications
- [ ] End-to-end encryption

## License

Private project.
