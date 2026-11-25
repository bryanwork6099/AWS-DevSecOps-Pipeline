from flask import Flask, jsonify
import os

app = Flask(__name__)


@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "application": "AWS DevSecOps Pipeline",
        "status": "running",
        "message": "Secure CI/CD deployment successful"
    })


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy"
    }), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))

    app.run(
        host="0.0.0.0",
        port=port
    )
