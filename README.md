<div align="center">

# 🌾 KisaanBandhu
### AI-Powered Crop Disease & Pest Management Platform

**SIH 2026 · Problem Statement 26131**

*Multilingual AI companion for Indian farmers — detect diseases, manage farms, get expert help.*

[![Flutter](https://img.shields.io/badge/Mobile-Flutter_3.x-02569B?logo=flutter)](https://flutter.dev)
[![NestJS](https://img.shields.io/badge/Backend-NestJS_10-E0234E?logo=nestjs)](https://nestjs.com)
[![Next.js](https://img.shields.io/badge/Dashboard-Next.js_15-000000?logo=nextdotjs)](https://nextjs.org)
[![MongoDB](https://img.shields.io/badge/DB-MongoDB-47A248?logo=mongodb)](https://mongodb.com)
[![Gemini](https://img.shields.io/badge/AI-Gemini_2.5_Flash-4285F4?logo=google)](https://ai.google.dev)

</div>

---

## 📖 Overview

**KisaanBandhu** (किसान बंधु — "Farmer's Friend") is a full-stack, production-ready platform that puts advanced AI in the hands of Indian farmers. A farmer can:

- **Scan any crop leaf** with their phone camera and get instant disease/pest diagnosis with severity and treatment advice
- **Draw and manage farm boundaries** on a GPS map
- **Talk to Krishi Mitra**, a voice-first AI mascot (Hindi & English), to get guidance, rename farms, navigate the app, and more — hands-free
- **Get outbreak alerts, weather, and government scheme info** from the Help Desk
- **Administrators** get a national outbreak heatmap dashboard showing real-time disease hotspots across India

The entire system works **offline** when there is no internet — the mobile app falls back to an on-device Gemma 3 1B model + RAG knowledge base.

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        KisaanBandhu                             │
│                                                                 │
│  ┌─────────────────┐    REST/WebSocket    ┌──────────────────┐  │
│  │  Flutter Mobile │◄────────────────────►│  NestJS Backend  │  │
│  │  (Farmer App)   │                      │  (Port 3000)     │  │
│  └────────┬────────┘                      └────────┬─────────┘  │
│           │                                        │            │
│  On-Device│AI (offline)              ┌─────────────┼──────────┐ │
│  ┌────────▼────────┐                 │    MongoDB  │          │ │
│  │ Gemma 3 1B +   │                 │  (Docker)   │          │ │
│  │ RAG (109 chunks)│                 └─────────────┘          │ │
│  └────────────────┘                           │               │ │
│                                               │ Gemini API    │ │
│  ┌─────────────────────────────────┐          ▼               │ │
│  │     Next.js Admin Dashboard     │   ┌──────────────┐       │ │
│  │     (Port 3001)                 │   │ Google Gemini │       │ │
│  │     National Outbreak Heatmap   │   │ 2.5 Flash     │       │ │
│  └─────────────────────────────────┘   └──────────────┘       │ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📱 Mobile App (Flutter)

### 🔬 Scan & Diagnose
- **Live camera scan** with real-time preview — tap the shutter to capture
- **Gallery upload** — pick from photo library
- **EfficientNetB0 V4 model** (trained on PlantVillage + custom Indian crop dataset)
  - 25+ disease / pest classes across rice, wheat, tomato, potato, maize, cotton, mango, banana
  - **Severity classification**: CRITICAL 🔴 / HIGH 🟠 / MEDIUM 🟡 / LOW 🟢
  - Confidence score displayed alongside diagnosis
- Results include: disease name, affected part, recommended pesticide/treatment, preventive measures
- Every scan is saved to detection history and synced to the backend

### 🗺️ Farm Map
- **Mapbox GL** satellite map with GPS location
- Draw farm boundaries by tapping points (polygon tool)
- Auto-calculates **acreage** in hectares and bighas
- Rename farms, delete farms, view all farms in list
- Multiple farms per user — each independently managed

### 🤖 Krishi Mitra — AI Mascot Agent
A floating 🌱 button that lives on every screen, powered by **Gemini 2.5 Flash** (online) or **Gemma 3 1B + RAG** (offline).

| Feature | Detail |
|---------|--------|
| **Wake Word** | "Hey Bandhu" / "हे बंधु" — always-on ambient detection |
| **"Start Demo" Action** | "Start demo" (spoken or typed) or tap 🚀 button — launches automated controlled app tour |
| **Demo Pause & Resume** | Tactile floating overlay button to pause demo mid-flow for judges, resume anytime |
| **Premium Light-Tint Focus** | Frosted glassmorphic cards, glowing emerald borders, and live synchronized speech subtitles |
| **Auto-restart** | STT re-arms every ~8s to survive Android's 10s timeout |
| **Hindi voice input** | Google STT in `hi_IN` locale → Devanagari script output |
| **Voice language toggle** | 🇮🇳 हिन्दी / 🇬🇧 English — switchable inside the chat sheet |
| **Domain guardrails** | Strictly scoped to KisaanBandhu + Indian agriculture; refuses off-topic queries |
| **Screen-context awareness** | Knows which screen you're on, which farm is selected, recent detection results |
| **Guided navigation** | Can navigate to any screen in the app on your behalf |
| **UI highlight** | Animates a spotlight ring on any UI element you ask about |
| **Farm rename** | Resolves farm by ID / name / "Farm 1" index / partial match; confirms before executing |
| **Human-in-the-Loop** | Write actions (rename, delete) show a confirmation card — user approves or rejects |
| **Offline fallback** | Seamlessly switches to on-device Gemma 3 + RAG with no data loss |
| **Overflow-free UI** | Chat sheet and confirmation cards handle long text gracefully |

### 🆘 Help Desk
- **Expert consultation** — submit crop problem; matched to agri-extension advisor
- **Disease outbreak alerts** — region-specific active alerts fetched from backend
- **Weather forecast** — 7-day weather for farm location
- **Government schemes** — PM-Kisan, PMFBY, KCC eligibility and how-to

### 👤 Profile
- Detection history with date, crop, disease, severity filters
- Language selector (Hindi / English — full app localisation)
- Account management (email, phone, profile picture)

### 📡 Offline Mode
- **Gemma 3 1B** (MediaPipe LLM Inference) runs entirely on-device
- **RAG knowledge base**: 109 chunks covering major Indian crop diseases, treatments, schemes
- ChromaDB-style vector search with cosine similarity
- Zero network dependency — full functionality in rural areas

---

## 🖥️ Admin Dashboard (Next.js)

A web-based administration panel for agriculture department officials and researchers.

### 🗺️ National Outbreak Heatmap
- **Interactive state-wise choropleth** — all 36 Indian states and union territories are shown; recorded detections determine the state shading, while areas without metric data use a neutral fill.
- **Distinct administrative boundaries** — state outlines are emphasized over thinner district boundaries, with hover highlights and state names / detection counts.
- **Expanded state view** — select a state on the map or in the state selector to open a larger map with its district boundaries, actual detection locations, severity heat halos, and state metrics. Switch states in the detail view, or close it with Escape, the close button, or an outside click.
- **Filter-aware, non-fabricated metrics** — state shading, counts, and heat intensity use dashboard-filtered detections (including Cotton / Soybean crop and severity filters); district lines are geographic reference only. The legend distinguishes detection severity and state-level intensity.
- **Detection heat halos** — concentric circles are centred on recorded detection coordinates; radius and color reflect detection severity. Halo size can be changed between Local, Standard, and Regional.
- **Map controls** — All India reset, zoom controls, and Esri Canvas / Satellite / Topographic tile layers.
- Administrative GeoJSON boundaries are loaded at runtime from the [India Maps Data boundary dataset](https://github.com/udit-001/india-maps-data/tree/cc91a19). An internet connection is needed to load these boundaries and Esri map tiles.

### 📊 Analytics
- **Outbreak data table** — sortable, searchable, filterable by severity / state / crop / date
- **State-wise breakdown chart** — bar chart of detections per state
- **Crop breakdown** — donut chart of affected crops
- **Disease breakdown** — top diseases by frequency
- **Timeline trend** — 30/60/90-day detection volume line chart
- **Summary KPIs** — total detections, critical alerts, affected states, active farms

---

## ⚙️ Backend (NestJS)

### Modules
| Module | Description |
|--------|-------------|
| `auth` | JWT sign-up / sign-in, bcrypt password hashing, refresh tokens |
| `users` | User profiles, preferences, language setting |
| `farms` | CRUD for farm polygons, acreage calculation |
| `detections` | Scan records — disease, severity, confidence, GPS coords |
| `alerts` | Regional outbreak alerts management |
| `agent` | Gemini LLM agent with tool calling, system-prompt guardrails, human-in-the-loop |

### Key API Endpoints
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/auth/register` | Public | Create account |
| `POST` | `/auth/login` | Public | Get JWT |
| `GET` | `/agent/health` | Public | Connectivity check from mobile |
| `POST` | `/agent/chat` | JWT | Send message to Krishi Mitra |
| `POST` | `/agent/action/confirm` | JWT | Confirm a human-in-the-loop action |
| `GET` | `/farms` | JWT | List user's farms |
| `POST` | `/farms` | JWT | Create farm |
| `PATCH` | `/farms/:id` | JWT | Update farm (name, boundary) |
| `DELETE` | `/farms/:id` | JWT | Delete farm |
| `POST` | `/detections` | JWT | Save scan result |
| `GET` | `/detections` | JWT | Detection history |
| `GET` | `/detections/heatmap` | JWT | Heatmap data for dashboard |
| `GET` | `/detections/analytics` | JWT | Aggregated analytics |
| `GET` | `/alerts` | JWT | Active outbreak alerts |

### Integrations
- **Google Gemini 2.5 Flash** — primary LLM for agent chat and tool calling
- **Meko** — persistent memory / conversation context store
- **Vapi + Twilio** — telephony integration for voice calls to the Help Desk
- **MongoDB** (via Prisma ODM) — primary data store
- **Docker Compose** — MongoDB + Mongo Express

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x, Dart, Mapbox GL, MediaPipe (Gemma 3 1B), google_mlkit_commons |
| AI (mobile) | EfficientNetB0 V4 (TFLite), Gemma 3 1B (on-device), RAG (ChromaDB-style, 109 chunks) |
| Voice | speech_to_text (Google STT), flutter_tts (TTS), hi_IN locale |
| Backend | NestJS 10, TypeScript, Prisma ODM, Passport JWT |
| Database | MongoDB 7 (Docker), Mongo Express |
| LLM (backend) | Google Gemini 2.5 Flash via `@google/generative-ai` SDK |
| Dashboard | Next.js 15 (App Router), React 19, Leaflet 2, Recharts, Tailwind CSS |
| Maps (dashboard) | Leaflet + Esri tile layers (satellite, topo, canvas) |
| Infra | Docker Compose, Bun (package manager), GitHub |

---

## 📋 Prerequisites

- **Node.js** ≥ 20 / **Bun** ≥ 1.1
- **Flutter** SDK ≥ 3.19 (`flutter doctor` clean)
- **Docker Desktop** (for MongoDB)
- **Mapbox account** (for mobile map)
- **Google AI Studio** API key (Gemini)
- **Android Studio / Xcode** for mobile emulator/device

---

## 🚀 Setup & Running

### 1. Clone the repository
```bash
git clone <your-repo-url> kisaanbandhu
cd kisaanbandhu
```

### 2. Start MongoDB (Docker)
```bash
docker-compose up -d
# MongoDB → localhost:27017
# Mongo Express UI → http://localhost:8081
```

### 3. Backend
```bash
cd backend

# Copy and fill environment variables
cp .env.example .env
# Edit .env with your GEMINI_API_KEY, JWT_SECRET, MONGODB_URI, etc.

# Install dependencies
bun install

# Run database migrations / generate Prisma client
bunx prisma generate

# Start development server (port 3000)
bun run start:dev
```

### 4. Admin Dashboard
```bash
cd dashboard

# Copy and fill environment variables
cp .env.example .env.local
# Set NEXT_PUBLIC_BACKEND_URL=http://localhost:3000

# Install dependencies
bun install

# Start development server (port 3001)
bun dev
```
Open → [http://localhost:3001](http://localhost:3001)

### 5. Mobile App
```bash
cd mobile

# Get Flutter packages
flutter pub get

# Set your Mapbox token in:
#   android/local.properties  →  MAPBOX_DOWNLOADS_TOKEN=sk.xxx
#   lib/config/app_config.dart  →  mapboxPublicToken

# Run on connected device / emulator
flutter run
```

---

## 🔐 Environment Variables

### `backend/.env` (copy from `.env.example`)

| Variable | Description |
|----------|-------------|
| `MONGODB_URI` | MongoDB connection string (e.g. `mongodb://localhost:27017/kisaanbandhu`) |
| `JWT_SECRET` | Secret key for JWT signing (generate a strong random string) |
| `JWT_EXPIRES_IN` | Token expiry (e.g. `7d`) |
| `GEMINI_API_KEY` | Google AI Studio API key |
| `MEKO_API_KEY` | Meko memory service API key |
| `VAPI_API_KEY` | Vapi telephony API key |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token |
| `PORT` | Backend port (default `3000`) |

### `dashboard/.env.local` (copy from `.env.example`)

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_BACKEND_URL` | Backend URL (e.g. `http://localhost:3000`) |

---

## 📁 Directory Structure

```
kisaanbandhu/
├── backend/                    # NestJS REST API
│   ├── src/
│   │   ├── agent/              # Krishi Mitra agent (Gemini + tool calling)
│   │   ├── auth/               # JWT authentication
│   │   ├── farms/              # Farm CRUD
│   │   ├── detections/         # Scan records + heatmap analytics
│   │   ├── alerts/             # Outbreak alerts
│   │   └── users/              # User profiles
│   ├── prisma/                 # Prisma schema (MongoDB ODM)
│   ├── .env.example            # Safe env template
│   └── nest-cli.json
│
├── dashboard/                  # Next.js Admin Dashboard
│   ├── src/
│   │   ├── app/                # Next.js App Router pages
│   │   ├── components/
│   │   │   ├── IndiaHeatmapMap.tsx     # Leaflet heatmap
│   │   │   ├── OutbreakDataTable.tsx   # Detection table
│   │   │   ├── OutbreakDetailModal.tsx # Hotspot detail modal
│   │   │   └── StatCharts.tsx          # Analytics charts
│   │   └── lib/api.ts          # Backend API client
│   └── .env.example
│
├── mobile/                     # Flutter Farmer App
│   ├── lib/
│   │   ├── screens/            # All app screens (Scan, Map, HelpDesk, Profile)
│   │   ├── services/
│   │   │   ├── voice_service.dart          # Wake word + STT (hi_IN)
│   │   │   ├── agent_runtime.dart          # Tool execution (rename, navigate, highlight)
│   │   │   ├── ai_mode_manager.dart        # Online/offline mode switching
│   │   │   └── backend_api_service.dart    # HTTP client for NestJS
│   │   ├── widgets/
│   │   │   ├── mascot/
│   │   │   │   ├── global_mascot_overlay.dart          # Floating 🌱 button + wake word
│   │   │   │   └── mascot_conversation_sheet.dart      # Chat UI + voice toggle
│   │   │   └── agent_highlight_overlay.dart            # Spotlight ring animation
│   │   └── repositories/       # FarmRepository, DetectionRepository
│   └── pubspec.yaml
│
├── rag/                        # Python RAG knowledge base builder
│   ├── build_rag.py            # Ingests agri docs → 109-chunk vector DB
│   └── knowledge/              # Source markdown/text documents
│
├── scripts/                    # Utility scripts (seed DB, test ML, etc.)
├── docker-compose.yml          # MongoDB + Mongo Express
├── firebase.json               # Firebase config (alerts / push notifications)
├── firestore.rules             # Firestore security rules
└── README.md
```

---

## 🤖 ML Model

The **EfficientNetB0 V4** model (`KisaanBandhu_EfficientNetB0_V4.keras`) is **not committed to this repository** due to its size (21 MB). Download it separately and place it in the project root before running the backend's model-serving script.

Similarly, the **Gemma 3 1B** weights are downloaded at runtime by the Flutter app via MediaPipe on first launch (~900 MB, Wi-Fi recommended).

> The `.zip` export (`plant_pest_classifier_FINAL_V4.zip`) is also excluded from git. See `.gitignore`.

---

## 🌐 Supported Languages

| Language | Mobile UI | Voice Input | AI Responses |
|----------|-----------|-------------|--------------|
| Hindi (हिन्दी) | ✅ Full | ✅ `hi_IN` STT | ✅ |
| English | ✅ Full | ✅ `en_IN` STT | ✅ |

---

## 📄 License

This project was developed for **Smart India Hackathon 2026** (Problem Statement 26131 — Ministry of Agriculture & Farmers' Welfare). All rights reserved.

---

<div align="center">
Made with ❤️ for Indian farmers · <em>किसान बंधु</em>
</div>
