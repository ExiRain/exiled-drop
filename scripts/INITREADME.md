# Exiled Drop — Setup & Scripts Guide

This folder contains all initialization and startup scripts for the Exiled Drop project.
Run them from the **project root** (`exiled-drop/`), not from inside `scripts/`.

## Prerequisites

Before running anything, make sure you have installed:

- **Java 21+** — `java -version` should show 21.x
  - Recommended: install via [SDKMAN](https://sdkman.io/) (`sdk install java 21.0.6-tem`)
  - Make sure `JAVA_HOME` points to JDK 21, not an older version
- **Docker & Docker Compose** — `docker --version` and `docker compose version`
- **Flutter 3.x** — `flutter --version` (needed later for frontend)

## Scripts — Run Order

For a **fresh setup**, run these in order:

| # | Script | Purpose |
|---|--------|---------|
| 1 | `scripts/check-prereqs.sh` | Verifies all required tools are installed and correct versions |
| 2 | `scripts/init-project.sh` | Generates Gradle wrapper, creates local config files |
| 3 | `scripts/start-infra.sh` | Starts PostgreSQL + coturn via Docker Compose |
| 4 | `scripts/start-backend.sh` | Builds and runs the Spring Boot backend |
| 5 | `scripts/seed-test-users.sh` | Creates two test users (alice & bob) for development |

For **daily development**, you typically only need:

```bash
./scripts/start-infra.sh       # if Docker containers aren't running
./scripts/start-backend.sh     # start the API
```

## Script Details

### check-prereqs.sh
Checks that Java 21+, Docker, Docker Compose, and (optionally) Flutter are installed.
Prints clear pass/fail for each tool with version info.
**Run this first on any new machine.**

### init-project.sh
- Generates the Gradle wrapper (`gradlew`) in the backend directory
- Creates `backend/src/main/resources/application-local.properties` from template
  (this file is gitignored — put your local overrides here)
- Runs a test compilation to verify everything is wired up

### start-infra.sh
- Starts PostgreSQL and coturn containers via Docker Compose
- Waits for PostgreSQL to be healthy before returning
- Idempotent — safe to run if containers are already up

### start-backend.sh
- Starts the Spring Boot backend with `./gradlew bootRun`
- Automatically uses the `local` Spring profile if `application-local.properties` exists
- Flyway runs migrations on startup — database schema is created automatically

### seed-test-users.sh
- Registers two test users via the API: `alice` / `password123` and `bob` / `password123`
- Prints their JWT tokens for quick testing with curl or Postman
- Idempotent — skips users that already exist

### stop-all.sh
- Stops the backend (if running in background) and all Docker containers
- Removes Docker volumes if `--clean` flag is passed

## Environment Variables

All scripts respect these optional environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `EXILED_DB_PASSWORD` | `exileddrop_secret` | PostgreSQL password |
| `EXILED_TURN_PASSWORD` | `turnpassword` | coturn TURN credential |
| `EXILED_API_PORT` | `8080` | Backend API port |
| `EXILED_JWT_SECRET` | (dev default) | JWT signing secret — **change in production** |

## Troubleshooting

**"Gradle requires JVM 17 or later"**
Your default Java is too old. Set `JAVA_HOME` to JDK 21:
```bash
export JAVA_HOME=/path/to/jdk-21
```
Or install via SDKMAN: `sdk install java 21.0.6-tem && sdk default java 21.0.6-tem`

**"Connection refused" on port 5432**
PostgreSQL container isn't running. Run `./scripts/start-infra.sh`

**"Connection refused" on port 8080**
Backend isn't running. Run `./scripts/start-backend.sh`

**Docker permission errors**
Add your user to the docker group: `sudo usermod -aG docker $USER` then log out/in.
