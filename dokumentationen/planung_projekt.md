# Projektplanung – M300 Fussball Dashboard

---

## 1. Ziele & Anforderungen

### Projektziel

Entwicklung und Deployment eines cloud-nativen Fussball Dashboards, das Live-Tabellen aus 5 europäischen Ligen anzeigt. Das Projekt demonstriert den Einsatz moderner DevOps- und Cloud-Technologien wie Docker, Kubernetes, CI/CD, Monitoring, Infrastructure as Code und Multi-Cloud-Deployment auf AWS und Azure.

### Funktionale Anforderungen

| Nr. | Anforderung |
|-----|-------------|
| F1 | Das Dashboard zeigt die aktuelle Tabelle von 5 Ligen an |
| F2 | Der Benutzer kann die Liga über ein Auswahlmenü wählen |
| F3 | Die Daten werden live von der football-data.org API abgerufen |
| F4 | Das System ist über eine öffentliche IP erreichbar |
| F5 | Bei jedem Push auf GitHub wird automatisch deployed |
| F6 | Die Applikation läuft eigenständig auf zwei Cloud-Anbietern (AWS und Azure) |

### Nicht-funktionale Anforderungen

| Nr. | Anforderung |
|-----|-------------|
| NF1 | Die Applikation läuft containerisiert und wird über Kubernetes orchestriert |
| NF2 | Die IP-Adresse ist statisch (Elastic IP / Static Public IP) |
| NF3 | Der Deploy-Prozess ist vollautomatisch (CI/CD) |
| NF4 | Der Code ist versioniert auf GitHub |
| NF5 | Die Infrastruktur ist als Code definiert (Terraform) |
| NF6 | Die Applikation skaliert automatisch je nach Last (Horizontal Pod Autoscaler) |
| NF7 | Der Betrieb wird überwacht (Prometheus & Grafana) |
| NF8 | Sicherheitsrelevante Daten (API Key) sind nicht im Klartext gespeichert |
| NF9 | Kommunikation ist über HTTPS/TLS abgesichert |
| NF10 | Der Zugriff zwischen Diensten ist durch Network Policies eingeschränkt |
| NF11 | Die Applikation startet nach einem Server-Neustart automatisch wieder |

---

## 2. Technologieentscheidungen & Begründungen

| Technologie | Entscheidung | Begründung |
|-------------|-------------|------------|
| **Cloud** | AWS EC2 & Azure VM | Multi-Cloud-Ansatz, Vergleich zweier Anbieter, guter Gratis-Tier bei beiden |
| **Backend** | Python Flask | Leichtgewichtig, einfach für REST APIs, gute Dokumentation |
| **Frontend** | HTML / CSS / JavaScript | Kein Framework nötig, einfach und schnell |
| **Datenquelle** | football-data.org API | Kostenloser API Key, zuverlässige Fussballdaten |
| **Containerisierung** | Docker | Industriestandard, portabel zwischen Umgebungen |
| **Orchestrierung** | Kubernetes (Minikube) | Automatisches Skalieren, Selbstheilung, industrieüblicher Standard |
| **CI/CD** | GitHub Actions | Direkt in GitHub integriert, kostenlos, einfache Konfiguration |
| **Infrastructure as Code** | Terraform | Provider-übergreifend (AWS & Azure), reproduzierbare Infrastruktur |
| **Monitoring** | Prometheus & Grafana (via Helm) | Industriestandard für Observability, gute Kubernetes-Integration |
| **Secrets Management** | Kubernetes Secrets | Verhindert Klartext-Speicherung sensibler Daten im Code |
| **Netzwerksicherheit** | Kubernetes Network Policy | Beschränkt Zugriff zwischen Pods nach Zero-Trust-Prinzip |
| **Transportverschlüsselung** | HTTPS/TLS via nginx Ingress | Verschlüsselte Kommunikation zum Client |
| **Statische IP** | Elastic IP (AWS) / Static Public IP (Azure) | Kein manuelles Update der IP nach Neustart nötig |

---

## 3. Aufgabenliste

| # | Aufgabe | Wann | Status |
|---|---------|------|--------|
| 1 | Projektidee definieren & genehmigen lassen | 28.05.2026 | Erledigt |
| 2 | GitHub Repository & Ordnerstruktur erstellen | 28.05.2026 | Erledigt |
| 3 | AWS EC2 Instanz erstellen & konfigurieren | 28.05.2026 | Erledigt |
| 4 | football-data.org API Key besorgen | 28.05.2026 | Erledigt |
| 5 | Flask Backend mit API-Anbindung entwickeln | 28.05.2026 | Erledigt |
| 6 | Frontend mit Auswahlmenü & Tabelle entwickeln | 04.06.2026 | Erledigt |
| 7 | 5 Ligen implementieren | 04.06.2026 | Erledigt |
| 8 | Elastic IP einrichten | 11.06.2026 | Erledigt |
| 9 | Docker installieren & Dockerfiles erstellen | 11.06.2026 | Erledigt |
| 10 | Kubernetes-Manifeste erstellen & Minikube deployen | 11.06.2026 | Erledigt |
| 11 | Horizontal Pod Autoscaler einrichten | 11.06.2026 | Erledigt |
| 12 | GitHub Actions CI/CD Workflow einrichten | 11.06.2026 | Erledigt |
| 13 | CI/CD End-to-End testen | 11.06.2026 | Erledigt |
| 14 | Prometheus & Grafana via Helm einrichten | 18.06.2026 | Erledigt |
| 15 | ServiceMonitor & Grafana Dashboard erstellen | 18.06.2026 | Erledigt |
| 16 | Terraform für AWS & Azure Grundinfrastruktur | 25.06.2026 | Erledigt |
| 17 | API Key als Kubernetes Secret, Network Policy, HTTPS/TLS | 25.06.2026 | Erledigt |
| 18 | Neuer unrestriktiver Azure Account & vollständige Migration | 02.07.2026 | Erledigt |
| 19 | Frontend-Redesign & Autostart-Service | 02.07.2026 | Erledigt |
| 20 | Security & Monitoring auf Azure übertragen | 09.07.2026 | Ausstehend |
| 21 | End-to-End Testing & Fehler beheben | 09.07.2026 | Ausstehend |
| 22 | Dokumentation finalisieren | 09.07.2026 | Ausstehend |
| 23 | Lernjournal abschliessen | 09.07.2026 | Ausstehend |
| 24 | Abgabe | 09.07.2026 | Ausstehend |

---

## 4. Umsetzung

### Wie ich die Ziele erreiche

**F1 & F2 – Ligatabellen mit Auswahlmenü**
Das Frontend wird mit HTML, CSS und JavaScript umgesetzt. Ein Auswahlmenü erlaubt die Wahl der Liga. Bei jeder Auswahl sendet JavaScript einen API-Call ans Backend, welches die Daten von football-data.org abruft, in ein einheitliches Format umwandelt und als JSON zurückgibt. Die Tabelle wird dynamisch im Browser gerendert.

**F3 – Live-Daten von football-data.org**
Das Flask Backend kommuniziert über HTTPS mit der football-data.org API. Der API-Key wird sicher als Kubernetes Secret gespeichert und über eine Umgebungsvariable ins Backend eingebunden, nie im Klartext im Code oder ans Frontend weitergegeben. Ein Endpoint (`/standings?competition=PL` etc.) liefert die Tabelle pro Liga.

**F4 – Öffentliche Erreichbarkeit**
Die Applikation läuft eigenständig auf einer AWS EC2 Instanz (statische Elastic IP) und einer Azure VM (statische Public IP). Auf beiden Umgebungen sind die entsprechenden Firewall-Regeln (AWS Security Group / Azure Network Security Group) so konfiguriert, dass Frontend (Port 8080) und Backend (Port 5000) erreichbar sind.

**F5 – Automatisches Deployment**
Ein GitHub Actions Workflow in `.github/workflows/deploy.yml` wird bei jedem Push auf den main Branch ausgelöst. Der Workflow verbindet sich per SSH auf den AWS EC2 Server, zieht den neuesten Code, baut die Docker Images neu und rollt das Kubernetes-Deployment neu aus. Auf Azure erfolgt das Deployment aktuell noch manuell.

**F6 – Multi-Cloud-Betrieb**
Über Terraform wurde sowohl auf AWS als auch auf Azure eigenständige Infrastruktur aufgebaut. Auf Azure musste dafür ein neuer, unabhängiger Account erstellt werden, da der ursprüngliche Account über eine schulseitige Tenant-Policy stark eingeschränkt war. Die komplette Applikation (Backend, Frontend, Kubernetes-Cluster) wurde anschliessend auf der Azure-VM eigenständig neu aufgebaut.

**NF1 – Containerisierung & Orchestrierung**
Backend und Frontend laufen je in einem eigenen Docker Container. Statt docker-compose wird Kubernetes (Minikube) zur Orchestrierung eingesetzt, was Selbstheilung, automatisches Skalieren und ein produktionsnäheres Setup ermöglicht.

**NF3 – CI/CD Pipeline**
Die CI/CD Pipeline mit GitHub Actions stellt sicher, dass jede Codeänderung automatisch auf dem AWS-Server landet. Der Entwickler muss sich nicht mehr manuell per SSH einloggen.

**NF5 – Infrastructure as Code**
Mit Terraform wird die gesamte Infrastruktur (EC2-Instanz, Azure Resource Group, Virtual Network, Subnet, Public IP, Network Security Group, Azure VM) deklarativ definiert und reproduzierbar bereitgestellt.

**NF6 – Automatisches Skalieren**
Ein Horizontal Pod Autoscaler skaliert die Backend-Pods automatisch je nach CPU-Auslastung zwischen 2 und 5 Instanzen.

**NF7 – Monitoring**
Prometheus und Grafana werden über Helm (kube-prometheus-stack) im Cluster betrieben. Ein ServiceMonitor sammelt Applikationsmetriken, ein eigenes Grafana-Dashboard visualisiert diese.

**NF8, NF9, NF10 – Sicherheit**
Der API Key liegt als Kubernetes Secret vor. Eine Network Policy beschränkt eingehenden Traffic zum Backend ausschliesslich auf Anfragen vom Frontend. HTTPS wird über ein selbstsigniertes TLS-Zertifikat und den nginx Ingress Controller bereitgestellt.

**NF11 – Automatischer Start**
Ein systemd-Service startet Minikube und die notwendigen Port-Forwards automatisch, sobald die jeweilige Instanz hochfährt, sodass die Applikation auch nach einem Neustart ohne manuellen Eingriff wieder erreichbar ist.
