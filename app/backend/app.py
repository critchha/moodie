from flask import Flask
import os

def create_app():
    app = Flask(__name__, static_folder='../frontend', static_url_path='/')
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')
    app.config['DEBUG'] = True

    # Import and register blueprints
    from app.backend.routes.recommend import recommend_bp
    from app.backend.routes.feedback import feedback_bp
    from app.backend.routes.train import train_bp
    app.register_blueprint(recommend_bp)
    app.register_blueprint(feedback_bp)
    app.register_blueprint(train_bp)

    @app.route('/')
    def index():
        return '<h1>Welcome to the Mood-Based Plex Recommender Backend</h1>'

    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000, debug=True) 