from flask import Flask
import os

def create_app():
    app = Flask(__name__, static_folder='../frontend', static_url_path='/')
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')
    app.config['DEBUG'] = True

    @app.route('/')
    def index():
        return '<h1>Welcome to the Mood-Based Plex Recommender Backend</h1>'

    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000, debug=True) 