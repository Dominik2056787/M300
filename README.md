# Fussball-Resultate Dashboard

## Beschreibung
Dieses Repository enthält einen cloud-nativen Webservice, der aktuelle Fussball-Resultate und Tabellen anzeigt. Die Anwendung wird mit Docker containerisiert und über AWS ECS in der Cloud betrieben. Die Deployment-Automatisierung erfolgt über eine CI/CD Pipeline mit GitHub Actions.

## Technologien
- Python (Flask) – Backend API
- Docker – Containerisierung
- AWS ECS – Container-Orchestrierung in der Cloud
- AWS ECR – Container Registry
- GitHub Actions – CI/CD Pipeline
- football-data.org API – Datenquelle für Fussballresultate

## Installation

1. Repository klonen:

   git clone https://github.com/Dominik2056787/M300/


2. API Key von football-data.org holen und .env Datei erstellen:

   API_KEY=dein_api_key_hier

3. Docker Image bauen und lokal starten:

   cd src/backend
   docker build -t fussball-backend .
   docker run -p 5000:5000 fussball-backend

4. Im Browser öffnen:

   XXX

## Projektstruktur

```
fussball-dashboard/
├── src/
│   ├── backend/       # Python Flask API
│   └── frontend/      # HTML/CSS/JS
├── config/            # ECS Konfigurationsdateien
├── docs/              # Projektdokumentation
├── lernjournal/       # Wöchentliche Lerneinträge
├── .github/workflows/ # CI/CD Pipeline
├── .gitignore
└── README.md
```


Dominik Hausammann
