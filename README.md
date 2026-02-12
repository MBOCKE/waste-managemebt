Waste Management System

A Progressive Web Application for efficient waste collection management. This system enables manual waste reporting, optimized routing, and real-time driver tracking using existing smartphones - no expensive hardware required.

---

🎯 Core Features

Module Capabilities
👥 User Management Email/OTP registration, role-based access (User/Driver/Admin), profile management

🗑️ Bin Management Register bins, track fill levels (0-100%), location pin-drop, QR code ready

📱 Waste Reporting One-tap reporting, photo upload (optional), daily reminders, cannot decrease until collection

🚛 Fleet Management Truck/driver registration, real-time GPS via smartphone, on/off duty modes

🗺️ Route Optimization Priority-based clustering, capacity planning, turn-by-turn directions via OSRM

📊 Live Monitoring Interactive OSM map, color-coded bins, driver trails, admin dashboard

🔔 Notifications Web Push API, daily reminders, route assignments, collection alerts

📱 PWA Installable, offline support, background sync, push notifications

---

🏗️ Tech Stack

Backend

Django 4.x + DRF     → REST API & admin interface

PostgreSQL + PostGIS → Spatial database & geoqueries

GeoDjango           → GIS operations & distance calculations

Celery + Redis      → Background tasks & route optimization

JWT + Allauth       → Authentication & OTP verification


Frontend

React 19 + TypeScript → Type-safe components & hooks

MUI v7               → Professional UI components

Leaflet + OSM        → Free, open-source maps

React Query          → Server state & caching

Vite 7              → Lightning-fast builds

PWA + Workbox       → Offline & installable


DevOps

Railway.app/Heroku/Render   → Hosting (free tier ready)

GitHub Actions       → CI/CD pipelines

Cloudinary          → Image uploads (optional)

---

📁 Project Structure

smart-waste/

├── backend/               # Django REST API + GeoDjango

│   ├── config/           # Project settings (base/dev/prod)

│   ├── apps/             # Modular Django apps

│   │   ├── users/       # Auth, profiles, roles

│   │   ├── bins/        # Bin registration, tracking

│   │   ├── reports/     # Waste reporting

│   │   ├── fleet/       # Trucks, drivers, location

│   │   ├── routes/      # Route optimization

│   │   └── core/        # Shared utilities

│   └── scripts/         # Helper scripts
│
├── frontend/             # React PWA

│   ├── src/

│   │   ├── components/  # Reusable UI (common, maps, forms)

│   │   ├── pages/       # Route components (user, driver, admin)

│   │   ├── hooks/       # Custom React hooks

│   │   ├── services/    # API clients (Axios)

│   │   ├── store/       # Context providers

│   │   ├── types/       # TypeScript interfaces

│   │   ├── utils/       # Helpers (geocoding, dates)

│   │   └── pwa/         # Service worker registration

│   └── public/          # Static assets, manifest

│

├── docker-compose.yml    # Local development services

└── .github/             # GitHub Actions workflows

---

🚀 Quick Start (5 Minutes)

Prerequisites

· Python 3.11+
· Node.js 20+
· PostgreSQL 15+ with PostGIS
· Redis 7+

1. Clone & Setup
git clone https://github.com/MBOCKE/waste-managegemebt.git
cd smart-waste

2. Backend Setup
cd backend

# Virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Environment variables
cp .env.example .env
# Edit .env with your database credentials

# Database
python manage.py migrate
python manage.py createsuperuser

# Run server
python manage.py runserver

3. Frontend Setup
cd frontend

# Install dependencies
npm install

# Environment variables
cp .env.example .env
# Edit .env with API URL

# Run dev server
npm run dev

4. Docker (Alternative)
docker-compose up -d

Access the apps:

· Frontend: https://localhost:5173

· Backend API: http://localhost:8000/api

· Admin Panel: http://localhost:8000/admin

---

🧪 Testing

Backend
cd backend
pytest
coverage run --source='.' manage.py test
coverage report

Frontend
cd frontend
npm test
npm run test:coverage
npm run lint
npm run format

---

📦 Deployment

Backend (Railway.app/Render)
# Push to GitHub
git push origin main

# Railway auto-deploys from main branch
# Set environment variables in Railway dashboard

Frontend (Vercel/Netlify)
cd frontend
npm run build
# Deploy ./dist folder to your hosting provider

---

🗺️ API Documentation

Once running, visit:

· Swagger UI/Insomnia: http://localhost:8000/api/docs/

· ReDoc: http://localhost:8000/api/redoc/

Core Endpoints:

POST   /api/auth/login/          → JWT token

POST   /api/auth/register/       → New user + OTP

GET    /api/bins/               → List user bins

POST   /api/reports/            → Report fill level

GET    /api/routes/             → Get assigned route

POST   /api/driver/location/    → Update GPS position

---

👥 Team Onboarding

New Developer? Here's your first week:

Day Tasks

Day 1 Read SRS, setup project locally, run both servers

Day 2 Explore codebase structure, understand folder conventions

Day 3 Pick a small feature (e.g., bin registration form)

Day 4 Implement feature with tests

Day 5 Submit PR, review feedback

Coding Conventions:

· Backend: PEP 8, Django best practices, app per domain

· Frontend: ESLint + Prettier, functional components, named exports

· Git: Conventional Commits (feat:, fix:, docs:, chore:)

· PRs: At least 1 reviewer, all tests pass

---

🎯 MVP Success Metrics

· ✅ 80% of users report waste levels daily

· ✅ 30% reduction in collection route distance

· ✅ 95% system uptime during business hours

· ✅ <3s response time for core operations

---

🗺️ Roadmap

Phase 1: Foundation (Weeks 1-3)

· Project setup & CI/CD
· Authentication & user management
· Bin CRUD & basic reporting

Phase 2: Core Features (Weeks 4-6)

· One-tap reporting & reminders
· Fleet & driver management
· Basic route optimization

Phase 3: Real-Time (Weeks 7-9)

· Live GPS tracking
· Interactive maps
· Push notifications

Phase 4: Polish (Weeks 10-12)

· PWA enhancements
· Performance optimization
· Production launch

---

🤝 Contributing

1. Fork the repository
2. Create feature branch (git checkout -b feature/amazing-idea)
3. Commit changes (git commit -m 'feat: add amazing feature')
4. Push branch (git push origin feature/amazing-idea)
5. Open a Pull Request

PR Guidelines:

· Link related issue
· Update documentation
· Add/update tests
· Ensure CI passes

---

🆘 Support

· Documentation: /docs folder
· Issues: GitHub Issues
· Discussions: GitHub Discussions
· Email: mbockegabriel@gmail.com

---

📄 License

Copyright © 2026 Smart Waste Management System

🙏 Acknowledgments

· OpenStreetMap contributors for free map data
· OSRM project for routing engine
· Django & React communities
· Our beta testers and early adopters
