# Migrationsdokumentation – AWS → Azure

## 1. Ausgangslage

Bis zum 25.06.2026 lief die gesamte Applikation ausschliesslich auf einer AWS EC2 Instanz. Auf Azure bestand lediglich eine Resource Group als erste Multi-Cloud-Demonstration über Terraform. Nach Rücksprache mit Herrn Rohr wurde entschieden, dass für die volle Punktzahl im Bereich Multi-Cloud die komplette Laufzeitumgebung zusätzlich eigenständig auf Azure aufgebaut werden muss.

## 2. Migrationsstrategie: Re-Deployment statt Image-Kopie

Es wurde bewusst keine Server-Image-Kopie zwischen den Cloud-Anbietern vorgenommen (z. B. AMI-Export/Import), da dies technisch aufwendig, fehleranfällig und in der Praxis unüblich ist. Stattdessen wurde eine **Re-Deployment-Migration** durchgeführt: Die Infrastruktur wird über Terraform auf Azure neu provisioniert, während Anwendungscode, Container-Definitionen und Konfiguration unverändert aus dem GitHub-Repository übernommen werden. Dieses Vorgehen entspricht dem in der Praxis üblichen Vorgehen bei Cloud-zu-Cloud-Migrationen und wurde bewusst so gewählt, um den Sinn von Infrastructure as Code (Reproduzierbarkeit) direkt zu demonstrieren.

## 3. Hindernis: Eingeschränkter TBZ-Azure-Account

Der ursprüngliche Azure-for-Students-Account über die TBZ-E-Mail-Adresse war durch eine Tenant-weite Policy eingeschränkt („best available regions"), die die Erstellung praktisch aller Ressourcentypen (Storage Account, Key Vault, Cosmos DB, Virtual Network) in allen getesteten Regionen (East US, West Europe, Switzerland North) verhinderte. Dies wurde systematisch nachgewiesen, indem mehrere Regionen und Ressourcentypen sowohl über Terraform als auch direkt im Azure-Portal getestet wurden – beide Wege lieferten denselben Fehler (`RequestDisallowedByAzure`).

**Lösung:** Es wurde ein neuer, privater Azure-for-Students-Account mit persönlicher E-Mail-Adresse erstellt. Dadurch entstand ein eigener, von der TBZ unabhängiger Tenant ohne diese Einschränkung.

## 4. Migrationsschritte im Überblick

| # | Schritt | Werkzeug |
|---|---|---|
| 1 | Neuer Azure-Account, Login auf neuem Tenant | Azure CLI |
| 2 | Terraform-Provider auf neue Subscription/Tenant umgestellt | `main.tf` |
| 3 | Alten Ressourcengruppen-Eintrag aus Terraform-State entfernt | `terraform state rm` |
| 4 | Provider-Namespaces registriert (Network, Compute) | Azure CLI |
| 5 | Netzwerk (VNet, Subnet) via Terraform erstellt | Terraform |
| 6 | SSH-Key für neue VM erzeugt | `ssh-keygen` |
| 7 | Public IP, Network Security Group, Network Interface, VM via Terraform erstellt | Terraform |
| 8 | Per SSH auf neue VM verbunden | SSH |
| 9 | Laufzeitumgebung installiert (Docker, kubectl, Minikube, Helm) | apt, curl |
| 10 | Minikube gestartet, Repository geklont | Minikube, Git |
| 11 | Docker-Images gebaut, in Minikube geladen | Docker |
| 12 | Kubernetes Secret und Deployments angewendet | kubectl |
| 13 | Fehlerbehebung: Datenformat im Backend korrigiert | Code-Fix, Redeploy |
| 14 | Port-Forwarding eingerichtet, Funktionstest durchgeführt | kubectl |

Eine detaillierte Schritt-für-Schritt-Beschreibung mit allen Befehlen und Screenshots befindet sich in der Gesamtdokumentation, Teil 5.

## 5. Aufgetretene Probleme während der Migration

| Problem | Ursache | Lösung |
|---|---|---|
| `MissingSubscriptionRegistration` bei VNet-Erstellung | Neue Subscription hatte Netzwerk-Provider nicht registriert | `az provider register --namespace Microsoft.Network` |
| Gleicher Fehler bei VM-Erstellung | Compute-Provider nicht registriert | `az provider register --namespace Microsoft.Compute` |
| Frontend zeigte nach Deployment weiterhin altes Design | Minikube cached Docker-Images nach Tag, nicht nach Inhalt | Neuer, eindeutiger Image-Tag pro Änderung |
| Datentabelle blieb leer trotz Status 200 | Über GitHub geklonter Code enthielt ältere Backend-Version ohne Datenaufbereitung und mit falschem Parameternamen | Endpoint direkt auf der Azure-VM korrigiert, akzeptiert nun `competition` und `liga`, wandelt API-Antwort in flaches Array um |
| Port-Forward brach nach Pod-Neustart ab | `kubectl port-forward` bindet an einen bestimmten Pod, nicht an den Service | Nach jedem Rollout Port-Forward manuell neu gestartet |

## 6. Ergebnis

Die Applikation läuft seit dem 02.07.2026 vollständig eigenständig auf Azure – Netzwerk, VM und Anwendung wurden komplett neu aufgebaut, ohne Abhängigkeit zur AWS-Umgebung. Beide Umgebungen sind seither parallel und unabhängig voneinander in Betrieb. Ein Vergleich der beiden Umgebungen befindet sich in der Architekturdokumentation.

## 7. Offene Punkte nach der Migration

Nicht jeder Aspekt der AWS-Umgebung wurde bereits 1:1 auf Azure übertragen (siehe Wartungskonzept, Abschnitt „Offene Punkte"):

- CI/CD-Pipeline (aktuell nur für AWS)
- Monitoring mit Prometheus/Grafana
- Network Policy und HTTPS/TLS
- Automatischer Start nach Neustart (systemd-Service)

Diese Punkte sind für die letzte Projektwoche vor der Abgabe eingeplant.
