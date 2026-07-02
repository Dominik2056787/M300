# Zeitplan – M300 Fussball Dashboard

```mermaid
gantt
    title M300 Projekt Zeitplan
    dateFormat YYYY-MM-DD
    axisFormat %d.%m
    section Uebergreifend
    Lernjournal fuehren :done, jour1, 2026-05-28, 43d
    Dokumentation schreiben :done, dok1, 2026-05-28, 43d
    section Planung und Setup
    Projektidee waehlen und Lehrer Freigabe :done, plan1, 2026-05-28, 1d
    GitHub Repo und Ordnerstruktur anlegen :done, plan2, 2026-05-28, 1d
    EC2 Instance und API Key einrichten :done, plan3, 2026-05-28, 1d
    section Backend und Frontend
    Flask Backend und API Anbindung :done, app1, 2026-05-28, 1d
    Unterstuetzung fuer 5 Ligen :done, app2, 2026-06-04, 1d
    Frontend mit Dropdown und CSS :done, app3, 2026-06-04, 1d
    section Infrastruktur
    Elastic IP einrichten :done, infra1, 2026-06-11, 1d
    Docker Images und docker compose :done, infra2, 2026-06-11, 1d
    GitHub Actions CI CD Pipeline :done, infra3, 2026-06-11, 1d
    Kubernetes Deployment und Services :done, infra4, 2026-06-11, 1d
    Horizontal Pod Autoscaler :done, infra5, 2026-06-11, 1d
    section Monitoring
    App Metriken mit Flask Exporter :done, mon1, 2026-06-18, 1d
    Helm und kube prometheus stack :done, mon2, 2026-06-18, 1d
    ServiceMonitor und Grafana Dashboard :done, mon3, 2026-06-18, 1d
    section Terraform
    Infrastructure as Code fuer EC2 :done, tf1, 2026-06-25, 1d
    Terraform State und Multi-Cloud Grundlagen :done, tf2, 2026-06-25, 1d
    section Security
    HTTPS und TLS Zertifikate :done, sec1, 2026-06-25, 1d
    Kubernetes Secrets und Network Policies :done, sec2, 2026-06-25, 1d
    section Multi-Cloud Migration
    Neuer unrestriktiver Azure Account :done, mc1, 2026-07-02, 1d
    Azure VM Netzwerk und Compute via Terraform :done, mc2, 2026-07-02, 1d
    Vollstaendiges Redeployment auf Azure :done, mc3, 2026-07-02, 1d
    Frontend Redesign und Autostart Service :done, mc4, 2026-07-02, 1d
    section Abschluss
    Security und Monitoring auf Azure uebertragen :test0, 2026-07-09, 1d
    End to End Testing und Review :test1, 2026-07-09, 1d
    Dokumentation finalisieren :test2, 2026-07-09, 1d
    Abgabe :milestone, abgabe1, 2026-07-09, 0d
```

---

## Übersicht nach Datum

| Datum | Schwerpunkt |
|-------|-------------|
| Do, 28.05. | Planung, EC2 Setup, Flask Backend, API-Anbindung (krankheitsbedingt verkürzt) |
| Do, 04.06. | Frontend, 5 Ligen, CORS, CSS Styling |
| Do, 11.06. | Elastic IP, IP-Bug fix, Docker, CI/CD, Kubernetes, HPA (alles an einem Tag umgesetzt) |
| Do, 18.06. | Monitoring: Prometheus, Grafana, Helm, ServiceMonitor, Dashboard |
| Do, 25.06. | Terraform: Infrastructure as Code, Multi-Cloud Grundlagen (AWS + Azure Resource Group); Security: HTTPS/TLS, Kubernetes Secrets, Network Policies |
| Do, 02.07. | Vollständige Multi-Cloud Migration: neuer Azure Account, komplette Infrastruktur (VM, Netzwerk) via Terraform, Applikation komplett auf Azure redeployed, Frontend-Redesign, Autostart-Service |
| Do, 09.07. | Security/Monitoring auf Azure übertragen, End-to-End Testing, Review, Doku finalisieren, **Abgabe** |

---

### Version & Stand

Version vom 02.07.2026, der Zeitplan wird jede Woche aktualisiert nach dem neusten Stand.
Letzter Arbeitstag ist der 09.07.2026.
Aktueller Stand ist 02.07.2026, Woche 8 abgeschlossen.

Dominik Hausammann
