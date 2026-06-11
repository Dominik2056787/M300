# Projektplanung – M300 Fussball Dashboard
---

## 1. Ziele & Anforderungen

### Projektziel
Entwicklung und Deployment eines cloud-nativen Fussball Dashboards auf AWS EC2, das Live-Tabellen aus 5 europäischen Ligen anzeigt. Das Projekt demonstriert den Einsatz moderner DevOps-Technologien wie Docker und CI/CD.

### Funktionale Anforderungen

| Nr. | Anforderung |
|-----|-------------|
| F1 | Das Dashboard zeigt die aktuelle Tabelle von 5 Ligen an |
| F2 | Der Benutzer kann die Liga über ein Dropdown wählen |
| F3 | Die Daten werden live von der football-data.org API abgerufen |
| F4 | Das System ist über eine öffentliche IP erreichbar |
| F5 | Bei jedem Push auf GitHub wird automatisch deployed |

### Nicht-funktionale Anforderungen

| Nr. | Anforderung |
|-----|-------------|
| NF1 | Die Applikation läuft in Docker Containern |
| NF2 | Die IP-Adresse ist statisch (Elastic IP) |
| NF3 | Der Deploy-Prozess ist vollautomatisch (CI/CD) |
| NF4 | Der Code ist versioniert auf GitHub |

---

## 2. Technologieentscheidungen & Begründungen

| Technologie | Entscheidung | Begründung |
|-------------|-------------|------------|
| **Cloud** | AWS EC2 | Weit verbreitet, guter Gratis-Tier, einfacher SSH-Zugang |
| **Backend** | Python Flask | Leichtgewichtig, einfach für REST APIs, gute Dokumentation |
| **Frontend** | HTML / CSS / JavaScript | Kein Framework nötig, einfach und schnell |
| **Datenquelle** | football-data.org API | Kostenloser API Key, zuverlässige Fussballdaten |
| **Containerisierung** | Docker & docker-compose | Industriestandard, einfaches Management mehrerer Services |
| **CI/CD** | GitHub Actions | Direkt in GitHub integriert, kostenlos, einfache Konfiguration |
| **Elastic IP** | AWS Elastic IP | Statische IP, kein manuelles Update nach EC2-Neustart nötig |

---

## 3. Aufgabenliste

| # | Aufgabe | Wann | Status |
|---|---------|------|--------|
| 1 | Projektidee definieren & genehmigen lassen | 28.05.2026 | Erledigt |
| 2 | GitHub Repository & Ordnerstruktur erstellen | 28.05.2026 | Erledigt |
| 3 | AWS EC2 Instanz erstellen & konfigurieren | 28.05.2026 | Erledigt |
| 4 | football-data.org API Key besorgen | 28.05.2026 |  Erledigt |
| 5 | Flask Backend mit API-Anbindung entwickeln | 28.05.2026 |  Erledigt |
| 6 | Frontend mit Dropdown & Tabelle entwickeln | 05.06.2026 |  Erledigt |
| 7 | 5 Ligen implementieren | 05.06.2026 |  Erledigt |
| 8 | Elastic IP einrichten | 11.06.2026 |  Erledigt |
| 9 | Docker installieren & Dockerfiles erstellen | 11.06.2026 |  Erledigt |
| 10 | docker-compose.yml erstellen | 11.06.2026 |  Erledigt |
| 11 | GitHub Actions CI/CD Workflow einrichten | 11.06.2026 |  Erledigt |
| 12 | CI/CD End-to-End testen | 11.06.2026 |  Erledigt |
| 13 | End-to-End Testing & Fehler beheben | 02.07.2026 |  Ausstehend |
| 14 | Dokumentation finalisieren | 02.07.2026 |  Ausstehend |
| 15 | Lernjournal abschliessen | 06.07.2026 |  Ausstehend |
| 16 | Abgabe | 09.07.2026 |  Ausstehend |
