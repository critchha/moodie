from flask import Flask, send_from_directory
import os

def create_app():
    from app.backend.config import DevelopmentConfig, TestingConfig, ProductionConfig
    app = Flask(__name__)

    # Select config class based on FLASK_ENV
    env = os.environ.get('FLASK_ENV', 'development')
    if env == 'production':
        app.config.from_object(ProductionConfig)
    elif env == 'testing':
        app.config.from_object(TestingConfig)
    else:
        app.config.from_object(DevelopmentConfig)

    # Import and register blueprints
    from app.backend.routes.recommend import recommend_bp
    from app.backend.routes.feedback import feedback_bp
    from app.backend.routes.train import train_bp
    from app.backend.routes.plex import plex_bp
    app.register_blueprint(recommend_bp)
    app.register_blueprint(feedback_bp)
    app.register_blueprint(train_bp)
    app.register_blueprint(plex_bp)

    # Register error handlers
    from app.backend.errors import register_error_handlers
    register_error_handlers(app)

    # Serve frontend index.html at root
    @app.route('/')
    def serve_index():
        frontend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../frontend'))
        print(f"[DEBUG] Resolved frontend_dir: {frontend_dir}")
        return send_from_directory(frontend_dir, 'index.html')

    # Serve static frontend files (js, css, etc.)
    @app.route('/<path:path>')
    def serve_static(path):
        frontend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../frontend'))
        return send_from_directory(frontend_dir, path)

    return app

if __name__ == '__main__':
    # Allow port override via command line or environment, but default to 8000
    import sys
    port = 8000
    for i, arg in enumerate(sys.argv):
        if arg in ('--port', '-p') and i + 1 < len(sys.argv):
            try:
                port = int(sys.argv[i + 1])
            except ValueError:
                pass
    app = create_app()
    app.run(host='0.0.0.0', port=port) 