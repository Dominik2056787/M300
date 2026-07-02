# Rollenkonzept – M300 Fussball Dashboard

## 1. Zweck

Dieses Dokument beschreibt, welche Personen- und Systemrollen im Projekt existieren und welche Berechtigungen sie jeweils haben. Da es sich um ein Einzelprojekt handelt, geht es hier nicht um die Aufteilung zwischen mehreren Teammitgliedern, sondern um die **technischen Rollen und Zugriffsrechte** innerhalb der Infrastruktur – analog zu einem IAM-/RBAC-Konzept in einer echten Cloud-Umgebung.

## 2. Personenrolle

| Rolle | Person | Aufgaben |
|---|---|---|
| Entwickler, Administrator, Betreiber | Dominik Hausammann | Entwicklung, Infrastruktur-Provisionierung, Betrieb, Wartung, Dokumentation – da Einzelprojekt in Personalunion |

## 3. Technische Rollen und Zugriffsrechte

| Rolle / Identität | Umgebung | Zugriff / Berechtigung | Verwendungszweck |
|---|---|---|---|
| AWS Academy Learner Lab Rolle | AWS | Temporäre Credentials (Access Key, Secret Key, Session Token), voller Zugriff innerhalb des Lab-Scopes | Terraform-Provisionierung, EC2-Verwaltung |
| SSH-User `ubuntu` | AWS EC2 | Administrativer Zugriff auf die Instanz (sudo) | Serverkonfiguration, Docker/Kubernetes-Betrieb |
| Azure Subscription Owner | Azure (privater Account) | Voller Zugriff auf die eigene Subscription | Terraform-Provisionierung, VM-Verwaltung |
| Azure Student Account (TBZ) | Azure (ursprünglicher Account) | Eingeschränkt durch Tenant-Policy (siehe Migrationsdokumentation) | Nicht mehr produktiv genutzt |
| SSH-User `azureuser` | Azure VM | Administrativer Zugriff auf die Instanz (sudo) | Serverkonfiguration, Docker/Kubernetes-Betrieb |
| GitHub Actions Deploy-Identität | AWS EC2 | SSH-Zugriff ausschliesslich auf die EC2-Instanz über hinterlegten Private Key (GitHub Secret) | Automatisiertes Deployment bei Push auf main |
| Kubernetes Default Service Account | Minikube (beide Umgebungen) | Standardrechte im `default`-Namespace, keine granulare RBAC-Einschränkung | Ausführung der Frontend-/Backend-Pods |
| Backend-Pod | Kubernetes | Lesezugriff ausschliesslich auf das Secret `football-api-secret` | API-Key-Nutzung zur Kommunikation mit football-data.org |
| Frontend-Pod | Kubernetes | Kein Zugriff auf Secrets | Ausliefern der statischen Weboberfläche |
| Backup-Skript (Cron) | AWS EC2 | Lesender Zugriff auf lokale Projektdateien, Schreibzugriff auf Azure Blob Storage über ausgelagerten Storage Account Key | Automatisierte tägliche Datensicherung |

## 4. Zugriff auf sensible Daten im Überblick

| Sensible Information | Wo gespeichert | Wer hat Zugriff |
|---|---|---|
| football-data.org API Key | Kubernetes Secret | Backend-Pod (über Umgebungsvariable) |
| TLS Private Key | Kubernetes Secret (Typ `tls`) | Ingress-Controller |
| SSH Private Key (AWS) | GitHub Repository Secret | GitHub-Actions-Workflow zur Laufzeit |
| SSH Private Key (Azure) | Lokal auf der AWS EC2, `~/.ssh/azure_key` | Nur der Benutzer `ubuntu` auf der EC2 |
| Azure Storage Account Key | `~/.azure_backup_key`, Rechte `chmod 600` | Nur der Benutzer `ubuntu` auf der EC2 |

## 5. Kritische Reflexion / offener Punkt

Aktuell ist innerhalb von Kubernetes **keine granulare RBAC-Konfiguration** eingerichtet – alle Pods laufen mit dem Standard-Service-Account im `default`-Namespace, und der Zugriff über `kubectl` erfolgt mit vollen Cluster-Rechten (`cluster-admin`), da Minikube standardmässig keine Einschränkung vornimmt. Für ein Schulprojekt mit einem einzelnen Nutzer ist dies vertretbar. In einer produktiven Mehrbenutzer-Umgebung würde man zusätzlich:

- Eigene Namespaces pro Komponente (z. B. `frontend`, `backend`, `monitoring`) einrichten
- Rollen (`Role`/`ClusterRole`) und Rollenbindungen (`RoleBinding`) definieren, die den Zugriff auf das jeweils benötigte Minimum beschränken (Least-Privilege-Prinzip)
- Getrennte Service Accounts für Frontend- und Backend-Pods verwenden, statt des Default-Accounts

<img width="624" height="565" alt="image" src="https://github.com/user-attachments/assets/3af6d9c1-8011-4926-b127-029c77533437" />
