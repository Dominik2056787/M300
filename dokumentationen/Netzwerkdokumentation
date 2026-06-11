# Netzwerkdokumentation – M300 Fussball Dashboard

---

## 1. Netzwerkdiagramm (Topologie)

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                             │
└──────────────┬──────────────────────────┬───────────────────┘
               │                          │
               ▼                          ▼
┌──────────────────────┐     ┌────────────────────────┐
│      Browser         │     │   football-data.org     │
│  (User / Client)     │     │        API              │
└──────────┬───────────┘     └────────────┬───────────┘
           │                              │
           │ HTTP                         │ HTTPS
           ▼                              │
┌─────────────────────────────────────────────────────────────┐
│                    AWS EC2 (Ubuntu)                         │
│                  IP: 34.205.190.81                          │
│                                                             │
│   ┌─────────────────────┐   ┌─────────────────────────┐    │
│   │  Docker Container   │   │   Docker Container      │    │
│   │     Frontend        │   │       Backend           │    │
│   │   Port: 8080        │◄──│     Port: 5000          │    │
│   │  (python http.server│   │   (Flask / Python)      │◄───┘
│   └─────────────────────┘   └─────────────────────────┘
│                                                             │
│              docker-compose (m300_default Network)          │
└─────────────────────────────────────────────────────────────┘
           ▲
           │
┌──────────────────────┐
│     GitHub Actions   │
│   (CI/CD Pipeline)   │
│  Auto-Deploy via SSH │
└──────────────────────┘
```

---

## 2. IP-Adressen & Ports

| Komponente | IP-Adresse | Port | Protokoll | Beschreibung |
|------------|-----------|------|-----------|-------------|
| EC2 Instanz (öffentlich) | 34.205.190.81 | — | — | Elastic IP, statisch |
| EC2 Instanz (intern) | 172.31.32.28 | — | — | Private IP im VPC |
| Frontend Container | 34.205.190.81 | 8080 | HTTP | Benutzeroberfläche |
| Backend Container | 34.205.190.81 | 5000 | HTTP | Flask REST API |
| SSH Zugang | 34.205.190.81 | 22 | SSH | Server-Administration & CI/CD Deploy |
| football-data.org API | extern | 443 | HTTPS | Fussballdaten |

---

## 3. AWS Security Groups / Firewall Rules

| Regel | Typ | Protokoll | Port | Quelle | Zweck |
|-------|-----|-----------|------|--------|-------|
| Inbound | SSH | TCP | 22 | Meine IP | Server-Administration |
| Inbound | Custom TCP | TCP | 5000 | 0.0.0.0/0 | Flask Backend erreichbar |
| Inbound | Custom TCP | TCP | 8080 | 0.0.0.0/0 | Frontend erreichbar |
| Outbound | All traffic | All | All | 0.0.0.0/0 | Ausgehender Traffic (API-Calls) |

---

