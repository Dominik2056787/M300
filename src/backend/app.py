from flask import Flask, jsonify, request
from flask_cors import CORS
import requests

app = Flask(__name__)
CORS(app)

API_KEY = "b3652669f46a4f0387f6bc50830cf2b0"

LIGEN = {
    "PL": "Premier League",
    "BL1": "Bundesliga",
    "PD": "La Liga",
    "SA": "Serie A",
    "FL1": "Ligue 1"
}

@app.route("/standings")
def standings():
    liga = request.args.get("liga", "PL")
    url = f"https://api.football-data.org/v4/competitions/{liga}/standings"
    res = requests.get(url, headers={"X-Auth-Token": API_KEY})
    table = res.json()["standings"][0]["table"]
    result = []
    for team in table:
        result.append({
            "position": team["position"],
            "team": team["team"]["name"],
            "points": team["points"]
        })
    return jsonify(result)

app.run(host="0.0.0.0", port=5000)
