# Zeitplan – M300 Fussball Dashboard

```mermaid
gantt
    title M300 Projekt Zeitplan
    dateFormat  YYYY-MM-DD
    axisFormat  %d.%m

    section Übergreifend
    Lernjournal führen                             :done,   jour1, 2026-05-28, 42d
    Dokumentation schreiben                        :done,   dok1,  2026-05-28, 42d

    section Planung & Setup
    Projektidee, GitHub Repo, EC2, API Key         :done,   plan1, 2026-05-28, 7d

    section Backend & Frontend
    Flask Backend, API-Anbindung, 5 Ligen          :done,   app1,  2026-05-28, 7d
    Frontend (HTML/JS), Dropdown, CSS              :done,   app2,  2026-06-04, 7d

    section Infrastruktur
    Elastic IP, IP-Bug fix, Security Groups        :done,   infra1, 2026-06-11, 1d

    section Docker
    Dockerfiles, Images bauen, docker-compose      :done,   dock1, 2026-06-11, 1d

    section CI/CD
    GitHub Actions, Auto-Build, SSH Deploy         :active, cicd1, 2026-06-18, 14d

    section Testing & Abschluss
    End-to-End Tests, Fehler beheben               :        test1, 2026-07-02, 4d
    Abschlusskontrolle & Review                    :        test2, 2026-07-06, 3d
    Abgabe                                         :milestone, 2026-07-09, 1d
```

---

## Übersicht nach Datum

| Datum | Schwerpunkt |
|-------|-------------|
| Do, 28.05. | Planung, EC2 Setup, Flask Backend, API-Anbindung |
| Do, 05.06. | Frontend, 5 Ligen, CORS, CSS Styling |
| Do, 11.06. | Elastic IP, IP-Bug fix, Docker, docker-compose |
| Do, 18.06. | GitHub Actions CI/CD einrichten |
| Do, 25.06. | CI/CD testen & optimieren |
| Do, 02.07. | End-to-End Testing |
| Do, 09.07. | Abschlusskontrolle, **Abgabe** |

### Version & Stand

Version vom 11.06.2026, der Zeitplan wird jede Woche Aktualisiert nach dem neusten Stand.

Aktueller Stand ist 11.06.2026 09:09:30 Uhr

Dominik Hausammann
