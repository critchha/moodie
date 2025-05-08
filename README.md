# Mood-Based Plex Recommender

A smart recommendation system that suggests Plex media content based on your current mood, session length, and feedback. Built with Flask, SQLite, and machine learning.

## Features
- Connects to your Plex server and imports media metadata
- Mood questionnaire and feedback UI
- Personalized recommendations using ML
- Easy-to-use web interface

## Installation
1. Clone the repository:
   ```sh
   git clone <repo-url>
   cd plex
   ```
2. Create a virtual environment and install dependencies:
   ```sh
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```
3. Set up your Plex credentials and environment variables as needed.

## Usage
- Start the backend server:
  ```sh
  python app/backend/main.py
  ```
- Access the frontend at `http://localhost:5000` (or as configured).

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
