#
# ckatsak, Thu Nov 13 05:51:21 AM EET 2025
# ckatsak, Sun Jun  7 06:28:24 PM EEST 2026
#

import json
import time
import traceback

from flask import Flask, jsonify, request
from werkzeug.exceptions import HTTPException

try:
    import ptpsync
except ImportError:
    app.logger.warn("Module ptpsync not found")


HEADER_KEY_HANDLER_DURATION = "handler-duration-ns"
HEADER_KEY_RESPONSE_DURATION = "response-duration-ns"


app = Flask(__name__)


@app.route("/invoke", methods=["POST"])
def invoke():
    response_start = time.perf_counter_ns()
    app.logger.debug("New invocation request...")

    if "ptpsync" in globals():
        app.logger.debug("Syncing system clock with host")
        try:
            ptpsync.clock_to_sys()
        except Exception as exc:
            app.logger.warning(
                f"Failed to sync system clock: {exc}",
                stack_info=True,
                exc_info=True,
            )

    function_input = request.get_json(force=True)
    app.logger.debug(f"function_input: {function_input}")
    function_input["payload"] = bytes(function_input["payload"])

    app.logger.debug("Calling function handler...")
    handler_start = time.perf_counter_ns()
    global function_handler
    if "function_handler" not in globals():
        from function_handler import function_handler
    function_output = function_handler(function_input)
    handler_duration_ns = time.perf_counter_ns() - handler_start
    app.logger.debug("Function handler returned successfully!")

    resp = jsonify({"output": str(function_output)})
    resp.headers[HEADER_KEY_HANDLER_DURATION] = handler_duration_ns
    resp.headers[HEADER_KEY_RESPONSE_DURATION] = (
        time.perf_counter_ns() - response_start
    )
    app.logger.debug("Returning successful Response...")
    return resp, 200


@app.route("/health", methods=["GET", "POST"])
def health():
    return "", 200


# Handler for all standard HTTP exceptions (4xx and 5xx that are HTTPExceptions).
# See <https://flask.palletsprojects.com/en/stable/errorhandling/#generic-exception-handlers>
@app.errorhandler(HTTPException)
def handle_http_exception(e):
    """Return JSON instead of HTML for HTTP errors."""

    # start with the correct headers and status code from the error
    resp = e.get_response()
    # replace the body with JSON
    resp.data = json.dumps(
        {
            "code": e.code,
            "name": e.name,
            "description": e.description,
        }
    )
    resp.content_type = "application/json"
    return resp


# Handler for all other exceptions.
# See <https://flask.palletsprojects.com/en/stable/errorhandling/#generic-exception-handlers>
@app.errorhandler(Exception)
def handle_exception(e):
    """Return JSON instead of HTML for all errors."""

    # log the full traceback for debugging purposes
    app.logger.error(traceback.format_exc())

    # pass through HTTP errors
    if isinstance(e, HTTPException):
        return e
    # now we're handling non-HTTP exceptions only

    response = jsonify(
        {
            "code": 500,
            "name": "Internal Server Error",
            "description": traceback.format_exc(),
        }
    )
    return response, 500


if __name__ == "__main__":
    app.run(debug=False)
