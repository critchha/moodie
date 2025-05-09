from flask import jsonify
import traceback
import logging

class AppError(Exception):
    def __init__(self, message, status_code=400):
        super().__init__(message)
        self.status_code = status_code

def register_error_handlers(app):
    @app.errorhandler(AppError)
    def handle_app_error(error):
        logging.error(f"AppError: {error}")
        response = jsonify({'error': str(error)})
        response.status_code = error.status_code
        return response

    @app.errorhandler(400)
    def bad_request(error):
        logging.error(f"400 Bad Request: {error}")
        return jsonify({'error': 'Bad request'}), 400

    @app.errorhandler(401)
    def unauthorized(error):
        logging.error(f"401 Unauthorized: {error}")
        return jsonify({'error': 'Unauthorized'}), 401

    @app.errorhandler(404)
    def not_found(error):
        logging.error(f"404 Not Found: {error}")
        return jsonify({'error': 'Not found'}), 404

    @app.errorhandler(500)
    def internal_error(error):
        logging.error(f"500 Internal Server Error: {error}")
        traceback.print_exc()
        return jsonify({'error': 'Internal server error'}), 500

    @app.errorhandler(501)
    def not_implemented(error):
        logging.error(f"501 Not Implemented: {error}")
        return jsonify({'error': 'Not implemented'}), 501 