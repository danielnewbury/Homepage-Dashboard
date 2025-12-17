from flask import Flask, request
import os
import json

app = Flask(__name__)

OK_FILE = "/indicator/OK"

@app.route("/alert", methods=["POST"])
def alert():
    data = request.get_json(force=True, silent=True) or {}
    status = data.get("status")

    app.logger.info("Received alert payload: %s", json.dumps(data))

    if status == "firing":
        if os.path.exists(OK_FILE):
            os.remove(OK_FILE)
            app.logger.warning("ALERT FIRING — OK file removed")
    elif status == "resolved":
        open(OK_FILE, "w").close()
        app.logger.info("ALERT RESOLVED — OK file restored")

    return "ok", 200


@app.route("/health", methods=["GET"])
def health():
    return "ok", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
