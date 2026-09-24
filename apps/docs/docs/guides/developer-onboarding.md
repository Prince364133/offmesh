---
sidebar_position: 1
title: Developer Onboarding Guide
---

# Developer Onboarding & Quickstart

Welcome to the NearLink open-source developer community! This guide walks you through setting up your local environment, building the apps, and running the automated test suites.

---

## 1. Prerequisites & Toolchain

Ensure your development computer has the following tools installed:

* **Node.js:** v20.x or v24.x LTS (`node -v`)
* **npm:** v10.x or v11.x (`npm -v`)
* **Flutter SDK:** v3.27+ (`flutter --version`)
* **Dart SDK:** v3.6+ (`dart --version`)
* **Java Development Kit (JDK):** OpenJDK 17 or 21 (`java -version`)
* **Android SDK:** Platforms 33–36 with `adb` in your system `PATH`
* **Docker & Docker Compose:** Optional for local PostgreSQL and Redis

---

## 2. Monorepo Setup

Clone the repository and install dependencies for each application:

```bash
git clone https://github.com/your-org/offline-messaging.git
cd offline-messaging

# 1. Setup Backend Modular Monolith
cd apps/backend
npm install

# 2. Setup Flutter Mobile App
cd ../mobile
flutter pub get

# 3. Setup Documentation Portal
cd ../docs
npm install
```

---

## 3. Running Automated Tests

All changes must pass the full 35-case automated test suite across Java, TypeScript, and Flutter:

### Step 1: Core Protocol Engine (Java 21)
```powershell
# Windows PowerShell
.\build.ps1

# Linux / macOS
./build.sh
```
*Expected: 22 passed, 0 failed.*

### Step 2: Backend Modular Monolith (TypeScript)
```bash
cd apps/backend
npm test
```
*Expected: 8 passed, 0 failed (Challenge auth, bundle mailboxes, anti-packets, Merkle diff).*

### Step 3: Flutter Cross-Platform Client (Dart)
```bash
cd apps/mobile
flutter test
```
*Expected: 5 passed, 0 failed (Card formatting, safety codes, status progression, Merkle root).*

---

## 4. Launching the Applications

### Running the Backend API with Interactive Swagger UI
```bash
cd apps/backend
npm run dev
```
* Interactive Swagger UI: [http://localhost:3000/docs](http://localhost:3000/docs)
* Health endpoint: [http://localhost:3000/health](http://localhost:3000/health)
* WebSocket Gateway: `ws://localhost:3000/ws`

### Running the Flutter Mobile Client
```bash
cd apps/mobile
flutter run
```
* Automatically targets connected Android device, emulator, iOS simulator, or Windows desktop.

### Running the Documentation Portal
```bash
cd apps/docs
npm start
```
* Local Docusaurus portal: [http://localhost:3000](http://localhost:3000)
