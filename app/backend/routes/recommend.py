from flask import Blueprint, request, jsonify, session
from app.backend.plex_client import PlexClient
from app.backend.errors import AppError
import random

recommend_bp = Blueprint('recommend', __name__)

# Map (mood, vibe) to preferred genres
MOOD_VIBE_GENRE_MAP = {
    ('angry', 'funny'): ['Comedy', 'Animation'],
    ('angry', 'relaxing'): ['Family', 'Animation', 'Romance'],
    ('angry', 'dramatic'): ['Drama', 'Thriller', 'Action'],
    ('angry', 'uplifting'): ['Adventure', 'Family', 'Music'],
    ('sad', 'uplifting'): ['Family', 'Adventure', 'Animation', 'Music'],
    ('sad', 'funny'): ['Comedy', 'Family'],
    ('sad', 'dramatic'): ['Drama', 'Romance'],
    ('sad', 'relaxing'): ['Family', 'Animation', 'Romance'],
    ('happy', 'funny'): ['Comedy', 'Family', 'Animation'],
    ('happy', 'relaxing'): ['Family', 'Animation', 'Romance'],
    ('happy', 'dramatic'): ['Drama', 'Adventure'],
    ('happy', 'uplifting'): ['Adventure', 'Music', 'Family'],
    ('stressed', 'funny'): ['Comedy', 'Animation'],
    ('stressed', 'relaxing'): ['Family', 'Animation', 'Romance'],
    ('stressed', 'dramatic'): ['Drama', 'Thriller'],
    ('stressed', 'uplifting'): ['Adventure', 'Family', 'Music'],
    ('neutral', 'any'): ['Drama', 'Documentary', 'Mystery', 'Comedy', 'Family'],
}
# Fallback for just mood
MOOD_GENRE_MAP = {
    'happy': ['Comedy', 'Family', 'Adventure', 'Animation'],
    'sad': ['Drama', 'Romance', 'Family', 'Music'],
    'neutral': ['Drama', 'Documentary', 'Mystery'],
    'stressed': ['Comedy', 'Animation', 'Adventure', 'Fantasy'],
    'angry': ['Action', 'Thriller', 'Crime', 'Adventure'],
}

@recommend_bp.route('/api/recommend', methods=['POST'])
def recommend():
    # Get Plex token and server name from session
    token = session.get('plex_token')
    server_name = session.get('plex_server_name')
    if not token:
        return jsonify({'error': 'Not connected to Plex'}), 401
    data = request.get_json() or {}
    mood = data.get('mood', '').lower()
    vibe = data.get('vibe', '').lower()
    group = data.get('group', '').lower()
    session_type = data.get('session', '').lower()
    # Select genres based on mood and vibe
    preferred_genres = []
    if vibe and vibe != 'any':
        preferred_genres = MOOD_VIBE_GENRE_MAP.get((mood, vibe), [])
    if not preferred_genres:
        preferred_genres = MOOD_GENRE_MAP.get(mood, [])
    client = PlexClient()
    try:
        server = client.connect_via_token(token, server_name)
        items = server.library.all()
        recommendations = []
        for item in items:
            if hasattr(item, 'type') and item.type in ('movie', 'show'):
                genres = [g.tag for g in getattr(item, 'genres', [])]
                # Filter by group (e.g., family-friendly)
                if group == 'family' and 'Family' not in genres:
                    continue
                # Filter by session (e.g., short: < 45min, long: > 90min)
                duration_min = getattr(item, 'duration', 0) / 60000
                if session_type == 'short' and duration_min > 45:
                    continue
                if session_type == 'long' and duration_min < 90:
                    continue
                recommendations.append({
                    'title': getattr(item, 'title', ''),
                    'type': item.type,
                    'summary': getattr(item, 'summary', ''),
                    'poster_url': item.posterUrl if hasattr(item, 'posterUrl') else '',
                    'year': getattr(item, 'year', None),
                    'genres': genres
                })
        # Rank by genre match to mood/vibe
        def genre_score(rec):
            return sum(1 for g in rec['genres'] if g in preferred_genres)
        recommendations.sort(key=genre_score, reverse=True)
        # Shuffle among top matches for variety
        top_score = genre_score(recommendations[0]) if recommendations else 0
        top_matches = [rec for rec in recommendations if genre_score(rec) == top_score and top_score > 0]
        if top_matches:
            random.shuffle(top_matches)
            final_recs = top_matches[:3]
        else:
            # Fallback: shuffle all recommendations
            random.shuffle(recommendations)
            final_recs = recommendations[:3]
        return jsonify({'recommendations': final_recs}), 200
    except AppError as e:
        return jsonify({'error': str(e)}), e.status_code
    except Exception as e:
        return jsonify({'error': str(e)}), 500
