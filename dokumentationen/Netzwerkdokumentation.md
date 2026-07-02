# Netzwerkdokumentation – M300 Fussball Dashboard



## 1. IP-Adressen & Ports

### AWS EC2

| Komponente | IP-Adresse | Port | Protokoll | Beschreibung |
|---|---|---|---|---|
| EC2 Instanz (öffentlich) | 34.205.190.81 | — | — | Elastic IP, statisch |
| EC2 Instanz (intern) | 172.31.32.28 | — | — | Private IP im VPC |
| Frontend (via port-forward) | 34.205.190.81 | 8080 | HTTP | Benutzeroberfläche |
| Backend (via port-forward) | 34.205.190.81 | 5000 | HTTP | Flask REST API |
| SSH Zugang | 34.205.190.81 | 22 | SSH | Server-Administration & CI/CD Deploy |
| Ingress (HTTPS) | 34.205.190.81 | 443 | HTTPS | Self-signed TLS über nginx Ingress |

### Azure VM

| Komponente | IP-Adresse | Port | Protokoll | Beschreibung |
|---|---|---|---|---|
| VM (öffentlich) | 20.203.129.36 | — | — | Static Public IP (Standard SKU) |
| VM (intern) | 10.0.1.4 | — | — | Private IP im Subnet |
| Frontend (via port-forward) | 20.203.129.36 | 8080 | HTTP | Benutzeroberfläche |
| Backend (via port-forward) | 20.203.129.36 | 5000 | HTTP | Flask REST API |
| SSH Zugang | 20.203.129.36 | 22 | SSH | Server-Administration |

### Extern

| Komponente | IP-Adresse | Port | Protokoll | Beschreibung |
|---|---|---|---|---|
| football-data.org API | extern | 443 | HTTPS | Fussballdaten |

## 2. Cluster-interne Netzwerkstruktur (Kubernetes)

Innerhalb von Minikube (auf beiden Umgebungen identisch aufgebaut):

| Service | Typ | Cluster-IP | Port | Beschreibung |
|---|---|---|---|---|
| frontend | NodePort | dynamisch | 8080:NodePort | Erreichbar via `kubectl port-forward` |
| backend | ClusterIP | dynamisch | 5000 | Nur innerhalb des Clusters erreichbar |

Eine **Network Policy** beschränkt eingehenden Traffic zum Backend-Pod ausschliesslich auf Anfragen von Frontend-Pods (Zero-Trust-Prinzip innerhalb des Clusters).

## 3. AWS Security Group (Firewall Rules)

| Regel | Typ | Protokoll | Port | Quelle | Zweck |
|---|---|---|---|---|---|
| Inbound | SSH | TCP | 22 | Meine IP | Server-Administration |
| Inbound | Custom TCP | TCP | 5000 | 0.0.0.0/0 | Flask Backend erreichbar |
| Inbound | Custom TCP | TCP | 8080 | 0.0.0.0/0 | Frontend erreichbar |
| Inbound | HTTPS | TCP | 443 | 0.0.0.0/0 | Ingress/TLS |
| Outbound | All traffic | All | All | 0.0.0.0/0 | Ausgehender Traffic (API-Calls) |

## 4. Azure Network Security Group (NSG)

| Regel | Priorität | Protokoll | Port | Quelle | Zweck |
|---|---|---|---|---|---|
| SSH | 1001 | TCP | 22 | * | Server-Administration |
| Frontend | 1002 | TCP | 8080 | * | Frontend erreichbar |
| Backend | 1003 | TCP | 5000 | * | Backend erreichbar |

## 5. Hinweis zur Sicherheit

Sowohl die AWS Security Group als auch die Azure NSG lassen Port 5000/8080 aktuell von überall zu (`0.0.0.0/0` bzw. `*`). Für die Schul-Demo ist das ausreichend; in einer echten Produktivumgebung würde man diese Regeln auf bestimmte IP-Bereiche einschränken.
