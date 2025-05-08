from flask import Blueprint, request, jsonify, session
from app.backend.plex_client import PlexClient
from app.backend.errors import AppError

plex_bp = Blueprint('plex', __name__)

@plex_bp.route('/api/plex/connect', methods=['POST'])
def plex_connect():
    data = request.get_json()
    token = data.get('token')
    server_name = data.get('server_name')
    if not token:
        return jsonify({'error': 'Missing Plex token'}), 400
    client = PlexClient()
    try:
        server = client.connect_via_token(token, server_name)
        # Store token and server name in session (or use secure credential store)
        session['plex_token'] = token
        session['plex_server_name'] = server.friendlyName if server else None
        return jsonify({'status': 'connected', 'server': server.friendlyName}), 200
    except AppError as e:
        return jsonify({'error': str(e)}), e.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@plex_bp.route('/api/plex/status', methods=['GET'])
def plex_status():
    token = session.get('plex_token')
    server_name = session.get('plex_server_name')
    if not token:
        return jsonify({'connected': False}), 200
    client = PlexClient()
    try:
        server = client.connect_via_token(token, server_name)
        return jsonify({'connected': True, 'server': server.friendlyName}), 200
    except Exception:
        return jsonify({'connected': False}), 200 