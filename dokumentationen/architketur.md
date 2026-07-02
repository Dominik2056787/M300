# Architekturdokumentation – M300 Fussball Dashboard

## 1. Überblick

Das M300 Fussball Dashboard ist als Multi-Cloud-Applikation aufgebaut: Dieselbe containerisierte Anwendung läuft eigenständig sowohl auf AWS als auch auf Azure, jeweils orchestriert über Kubernetes (Minikube). Die Architektur wurde so gewählt, dass sie die im Modul geforderten Konzepte (Containerisierung, Orchestrierung, CI/CD, Monitoring, Infrastructure as Code, Security, Multi-Cloud) an einem konkreten, funktionierenden Beispiel zeigt.

## 2. Architekturdiagramm

<img width="638" height="431" alt="image" src="https://github.com/user-attachments/assets/85726792-35ab-4cf4-bce1-d27cf91f83a7" />


*Browser und football-data.org API verbinden sich mit zwei eigenständigen Cloud-Umgebungen (AWS EC2 und Azure VM), die je einen Kubernetes-Cluster mit Frontend- und Backend-Pods betreiben. GitHub deployt automatisiert nach AWS, ein täglicher Cron-Job sichert von AWS aus ein Backup nach Azure Blob Storage. Monitoring, Network Policy und HTTPS sind aktuell nur auf AWS eingerichtet (siehe Abschnitt 6).*

## 3. Komponentenübersicht

| Schicht | Technologie | Begründung |
|---|---|---|
| Infrastruktur | Terraform | Deklarative, reproduzierbare, providerübergreifende Infrastruktur (AWS + Azure in derselben Konfiguration) |
| Compute | AWS EC2 / Azure VM | Zwei unabhängige Cloud-Umgebungen für den geforderten Multi-Cloud-Nachweis |
| Containerisierung | Docker | Portabilität der Applikation zwischen beiden Cloud-Umgebungen |
| Orchestrierung | Kubernetes (Minikube) | Selbstheilung, automatische Skalierung, produktionsnahe Betriebsweise |
| Backend | Python/Flask | Leichtgewichtige REST-API, ruft football-data.org auf und liefert aufbereitete Daten |
| Frontend | HTML/CSS/JavaScript | Ruft das Backend auf und stellt die Ligatabellen dar |
| CI/CD | GitHub Actions | Automatisiertes Deployment bei jedem Push (aktuell nur für AWS) |
| Monitoring | Prometheus & Grafana (Helm) | Beobachtbarkeit von Traffic, Fehlerrate, Antwortzeit und Ressourcenverbrauch |
| Security | Kubernetes Secrets, Network Policy, TLS/Ingress | Schutz von Zugangsdaten, Einschränkung der Pod-Kommunikation, verschlüsselte Übertragung |
| Backup | Azure Blob Storage, Cron-Job | Tägliche automatische Datensicherung, Disaster Recovery |

## 4. Datenfluss

1. Der Benutzer öffnet das Dashboard im Browser über die öffentliche IP der jeweiligen Cloud-Instanz.
2. Das Frontend (statisches HTML/JS, ausgeliefert durch einen Python-HTTP-Server im Container) lädt im Browser und sendet eine Anfrage an das Backend.
3. Das Backend (Flask) ruft die football-data.org API auf, unter Verwendung eines API-Keys, der als Kubernetes Secret hinterlegt ist (nicht im Code).
4. Die Antwort der API wird im Backend in ein einfaches, flaches Format umgewandelt und als JSON an das Frontend zurückgegeben.
5. Das Frontend rendert die Tabelle dynamisch im Browser.
6. Parallel dazu sammelt Prometheus (auf AWS) laufend Metriken vom Backend, die in Grafana visualisiert werden.
7. Täglich sichert ein Cron-Job das gesamte Projektverzeichnis nach Azure Blob Storage.

## 5. Multi-Cloud-Prinzip

Die Applikation wurde bewusst nicht nur mit einer einzelnen Ressource auf einer zweiten Cloud (z. B. nur ein Storage Account), sondern vollständig eigenständig auf beiden Cloud-Anbietern aufgebaut. Das zeigt, dass die gewählte Architektur (Container + Kubernetes + Terraform) tatsächlich providerunabhängig ist und nicht an einen einzelnen Anbieter gebunden ist – ein zentrales Argument für Multi-Cloud-Fähigkeit in der Praxis. Details zur Umsetzung dieser Migration sind im separaten Migrationsdokument beschrieben.

## 6. Bekannte Unterschiede zwischen den beiden Umgebungen

| Aspekt | AWS | Azure |
|---|---|---|
| CI/CD | Automatisiert (GitHub Actions) | Manuell |
| Monitoring | Prometheus/Grafana eingerichtet | Noch nicht eingerichtet |
| Network Policy / TLS | Eingerichtet | Noch nicht übertragen |
| Autostart nach Neustart | systemd-Service eingerichtet | Noch nicht übertragen |

Diese Unterschiede sind im Wartungskonzept unter „Offene Punkte" festgehalten.
