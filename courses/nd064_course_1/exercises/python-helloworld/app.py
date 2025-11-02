import json
import logging
from flask import Flask
app = Flask(__name__)

def setup_logging():
    formatter = logging.Formatter("%(asctime)s %(levelname)s: %(message)s")

    file_handler = logging.FileHandler("app.log")
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)

    app.logger.setLevel(logging.DEBUG)
    app.logger.addHandler(file_handler)

    # Also capture Werkzeig logs (for request info)
    werkzeug_logger = logging.getLogger("werkzeug")
    werkzeug_logger.setLevel(logging.INFO)
    werkzeug_logger.addHandler(file_handler)

@app.route("/")
def hello():
    app.logger.info("Route hello")
    return "Hello World!"

@app.route("/status")
def status():
    app.logger.debug("Route status")
    response = app.response_class(
        response=json.dumps({"result": "OK -healthy"}),
        status=200,
        mimetype="application/json"
    )
    return response

@app.route("/metrics")
def metrics():
    app.logger.debug("Route metrics")
    response = app.response_class(
        response=json.dumps({"status": "success", "code": 0, "data": {"UserCount": 130,"UserCountActive": 24}}),
        status=200,
        mimetype="application/json"
    )
    return response

if __name__ == "__main__":
    setup_logging()
    app.run(host='0.0.0.0')
