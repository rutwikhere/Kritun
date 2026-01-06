# Kritun 🎮  
*A Social Gaming Community & Team Discovery Platform*

Kritun is a mobile-first social platform built for gamers to **discover teams, teammates, and gaming communities** based on verified skills, language compatibility, and trust.  
It combines **team matchmaking**, **trial-based verification**, and **social engagement** into a single ecosystem.

---

## 🚀 Overview

Finding the right gaming teammates is hard — ranks are unreliable, communication is mismatched, and trust is missing.  
**Kritun solves this** by enabling players and teams to:

- Discover each other using **game, rank, language, and region**
- Verify skills via **trial games (“Let’s play once”)**
- Build trust through **ratings & feedback**
- Engage socially using **Krits (posts), reactions, comments, and follows**

---

## ✨ Key Features

### 👤 Player Profiles
- Multi-game profiles with ranks, roles, and in-game IDs  
- Language-aware discovery (filter by spoken languages)
- Public profile with achievements and stats

### 👥 Teams & Sub-Teams
- Create teams and game-specific sub-teams  
- Role-based team management (Owner / Admin / Member)
- Post vacancies and invite players

### 🔁 Matchmaking & Trials
- Player ↔ Team join & invite requests  
- **Trial games** before permanent joining  
- Post-trial ratings & feedback system

### 🧠 Trust & Safety
- Ratings for players and teams
- Reporting system for abuse or misconduct
- Admin moderation support (MVP-level)

### 📰 Community (Krits)
- Post short updates (“Krits”)
- Like, comment, repost
- Follow players and teams
- Engagement-driven feed

---

## 🛠 Tech Stack

### Frontend
- **Flutter (Dart)**
- Material UI
- Responsive mobile-first design

### Backend & Services
- **Firebase**
  - Authentication
  - Firestore
  - Cloud Functions
  - Cloud Messaging (FCM)
- **Supabase**
  - Media storage
  - Server-side cleanup & scheduling

### Platforms
- Android (primary)
- Web / Desktop (experimental support via Flutter)

---

## 📱 App Architecture (High-Level)

- Modular Flutter architecture
- Feature-based separation:
  - Auth & Onboarding
  - Profiles
  - Teams & Vacancies
  - Feed (Krits)
  - Notifications
- Cloud-driven backend for scalability

---

## 🔐 Security & Privacy

- Secure authentication via Firebase Auth
- HTTPS-only communication
- Sensitive credentials excluded via `.gitignore`
- No private keys or secrets committed

---

## 🧪 Current Status

- ✅ Core MVP features implemented
- 🚧 Advanced matchmaking & analytics in progress
- 🔜 Automatic rank sync via game APIs (planned)

---

## 🌱 Future Enhancements

- Game API integrations (Valorant, Steam, etc.)
- Advanced recommendation engine
- Web dashboard for teams & admins
- In-app tournaments and events
- Voice & language-based matching

---

## 🤝 Contributing

This project is currently under active development.  
Contributions, suggestions, and feedback are welcome.

---

## 📄 License

This project is currently private / unlicensed.  
License will be added before public release.

---

## Get it on Google Playstore

Link - https://play.google.com/store/apps/details?id=com.techbrats.kritun


---

## 👨‍💻 Author

**Rutwik Wakale**  
B.Tech IT (Business Informatics), IIIT Allahabad  
Flutter Developer | Mobile App Enthusiast  

🔗 GitHub: https://github.com/rutwikhere  
🔗 LinkedIn: https://www.linkedin.com/in/rutwikhere/

---

> Kritun is built with the vision of creating **trusted, language-aware gaming communities** — not just teams.
