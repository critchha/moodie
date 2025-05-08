from flask import jsonify

class AppError(Exception):
    def __init__(self, message, status_code=400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def register_error_handlers(app):
    @app.errorhandler(404)
    def not_found(error):
        return jsonify({
            'error': 'Not Found',
            'message': 'The requested resource was not found.',
            'status': 404
        }), 404

    @app.errorhandler(500)
    def internal_error(error):
        return jsonify({
            'error': 'Internal Server Error',
            'message': 'An unexpected error occurred.',
            'status': 500
        }), 500

    @app.errorhandler(AppError)
    def handle_app_error(error):
        return jsonify({
            'error': 'Application Error',
            'message': error.message,
            'status': error.status_code
        }), error.status_code 