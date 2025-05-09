from flask import Blueprint, request, jsonify, session, current_app, url_for
from plex_client import PlexClient
from errors import AppError
import random
from datetime import datetime
import logging
from database import get_session, Media, Recommendation, Feedback, add_record
from sqlalchemy.orm.exc import NoResultFound
import threading
import time
import hashlib
import os

recommend_bp = Blueprint('recommend', __name__)

MOOD_TAGS = {
    'light_funny': ['comedy', 'family', 'animation'],
    'intense': ['action', 'thriller', 'crime'],
    'emotional': ['drama', 'romance', 'biography'],
    'dramatic': ['musical', 'mystery', 'historical'],
}

# In-memory cache for recommendations
RECOMMEND_CACHE = {}
RECOMMEND_CACHE_LOCK = threading.Lock()
CACHE_TTL = 600  # 10 minutes

def make_cache_key(session_id, user, page, size):
    key_str = f"{session_id}:{user['time']}:{user['moods']}:{user['genres']}:{user['format']}:{user['comfortMode']}:{user['surprise']}:{page}:{size}"
    return hashlib.sha256(key_str.encode()).hexdigest()

def get_cached_recommendations(session_id, user, page, size):
    key = make_cache_key(session_id, user, page, size)
    with RECOMMEND_CACHE_LOCK:
        entry = RECOMMEND_CACHE.get(key)
        if entry and (time.time() - entry['ts'] < CACHE_TTL):
            return entry['data']
        elif entry:
            del RECOMMEND_CACHE[key]
    return None

def set_cached_recommendations(session_id, user, page, size, data):
    key = make_cache_key(session_id, user, page, size)
    with RECOMMEND_CACHE_LOCK:
        RECOMMEND_CACHE[key] = {'data': data, 'ts': time.time()}

def invalidate_cache_for_session(session_id):
    with RECOMMEND_CACHE_LOCK:
        keys = [k for k in RECOMMEND_CACHE if k.startswith(session_id)]
        for k in keys:
            del RECOMMEND_CACHE[k]

def filter_by_time(item, time_pref):
    d = item['duration']
    if time_pref in ('open', 'binge', 'any', None):
        return True
    if time_pref == 'under_1h':
        return d <= 60
    elif time_pref == '1_2h':
        return 60 < d <= 125
    elif time_pref == '2plus':
        return d > 125
    return True

def filter_by_format(item, fmt):
    return fmt == 'any' or item['type'] == fmt

def get_liked_disliked_attributes(session_id):
    session = get_session()
    feedbacks = session.query(Feedback).join(Recommendation).join(Media).filter(Recommendation.group_size == session_id).all()
    liked = {'genres': set(), 'directors': set(), 'cast': set()}
    disliked = {'genres': set(), 'directors': set(), 'cast': set()}
    for fb in feedbacks:
        rec = fb.recommendation
        media = rec.media
        if fb.rating == 5 or fb.would_watch_again is True:
            liked['genres'].update((media.genres or '').split(','))
            liked['directors'].update(getattr(media, 'directors', '').split(','))
            liked['cast'].update(getattr(media, 'cast', '').split(','))
        elif fb.rating == 1 or fb.would_watch_again is False:
            disliked['genres'].update((media.genres or '').split(','))
            disliked['directors'].update(getattr(media, 'directors', '').split(','))
            disliked['cast'].update(getattr(media, 'cast', '').split(','))
    session.close()
    # Remove empty strings
    for k in liked:
        liked[k] = set(x.strip() for x in liked[k] if x.strip())
        disliked[k] = set(x.strip() for x in disliked[k] if x.strip())
    return liked, disliked

def score_item(item, user, feedback_map=None, liked=None, disliked=None, surprise=False):
    score = 0
    genres = [g.lower() for g in item['genres']]
    directors = set(item.get('directors', []))
    cast = set(item.get('cast', []))
    # Comfort + Unwatched weighting
    if user['comfortMode']:
        if item['viewCount'] >= 3:
            score += 30  # Strong comfort bonus
    elif item['viewCount'] == 0:
        score += 10
    # Time fit
    if filter_by_time(item, user['time']):
        score += 10
    else:
        score += 5
    # Mood match (multi-select support)
    user_moods = user.get('moods') or [user.get('mood')] or []
    mood_tags = []
    for mood in user_moods:
        mood_tags.extend(MOOD_TAGS.get(mood, []))
    if any(tag in genres for tag in mood_tags):
        score += 10
    elif any(tag in item['summary'].lower() for tag in mood_tags):
        score += 5
    # Genre match (multi-select support)
    user_genres = user.get('genres') or []
    if user_genres:
        if any(g in genres for g in user_genres):
            score += 8
    # Format match
    if filter_by_format(item, user['format']):
        score += 5
    # Feedback adjustment
    if feedback_map:
        fb = feedback_map.get(item['title'])
        if fb == 'up':
            score += 15
        elif fb == 'down':
            score -= 20
    # Content-based filtering: boost for similarity to liked, demote for similarity to disliked
    if liked:
        if liked['genres'] and any(g in liked['genres'] for g in genres):
            score += 6
        if liked['directors'] and directors & liked['directors']:
            score += 4
        if liked['cast'] and cast & liked['cast']:
            score += 2
    if disliked:
        if disliked['genres'] and any(g in disliked['genres'] for g in genres):
            score -= 8
        if disliked['directors'] and directors & disliked['directors']:
            score -= 5
        if disliked['cast'] and cast & disliked['cast']:
            score -= 3
    # Surprise logic
    if surprise:
        score += random.randint(0, 5)
        if not (any(g in liked['genres'] for g in genres) or any(tag in genres for tag in mood_tags)):
            score += random.randint(0, 8)
    return score

def get_feedback_map(session_id):
    session = get_session()
    feedbacks = session.query(Feedback).join(Recommendation).join(Media).filter(Recommendation.group_size == session_id).all()
    feedback_map = {}
    for fb in feedbacks:
        rec = fb.recommendation
        media = rec.media
        if fb.rating == 1 or fb.would_watch_again is False:
            feedback_map[media.title] = 'down'
        elif fb.rating == 5 or fb.would_watch_again is True:
            feedback_map[media.title] = 'up'
    session.close()
    return feedback_map

def get_suggestions(media, user, feedback_map=None, liked=None, disliked=None, surprise=False, page=1):
    scored = [
        {'item': item, 'score': score_item(item, user, feedback_map, liked, disliked, surprise)}
        for item in media
    ]
    logging.info(f"Scored {len(scored)} items")
    scored = [entry for entry in scored if entry['score'] > 0]
    logging.info(f"{len(scored)} items passed score > 0 filter")
    # Always sort by score DESC, then by title ASC for stability
    scored.sort(key=lambda x: (-x['score'], x['item']['title']))
    N = 10
    # Only shuffle for first page and if surprise is on
    if page == 1 and surprise:
        random.shuffle(scored)
    elif page == 1 and not surprise:
        top_n = scored[:N]
        random.shuffle(top_n)
        scored = top_n + scored[N:]
    # For page > 1, do not shuffle at all
    recommendations = [entry['item'] for entry in scored]
    # Hybrid comfort mode: prepend top comfort items if comfortMode is on
    if user.get('comfortMode'):
        # Find top 3 most-watched items (viewCount >= 3), sorted by viewCount DESC
        comfort_items = sorted(
            [item for item in media if item.get('viewCount', 0) >= 3],
            key=lambda x: -x.get('viewCount', 0)
        )[:3]
        # Remove any duplicates from recommendations
        comfort_titles = set(item['title'] for item in comfort_items)
        recommendations = comfort_items + [item for item in recommendations if item['title'] not in comfort_titles]
    if not recommendations:
        fallback = sorted(media, key=lambda x: x.get('viewCount', 0), reverse=True)[:3]
        logging.info("No recommendations passed filter, using fallback by viewCount")
        recommendations = fallback
    # Deduplicate by title, preserving order
    seen_titles = set()
    deduped = []
    for item in recommendations:
        if item['title'] not in seen_titles:
            deduped.append(item)
            seen_titles.add(item['title'])
    logging.info(f"Returning {len(deduped)} recommendations: {[item.get('title', '') for item in deduped]}")
    return deduped

def filter_media(media, user):
    filtered = []
    user_format = user.get('format', 'any')
    user_time = user.get('time', '1_2h')
    user_genres = set([g.lower() for g in user.get('genres', [])])
    user_moods = user.get('moods') or []
    mood_tags = set()
    for mood in user_moods:
        mood_tags.update(MOOD_TAGS.get(mood, []))
    count_format = 0
    count_time = 0
    count_genre = 0
    count_mood = 0
    for item in media:
        # Format filter
        if user_format != 'any' and item['type'] != user_format:
            count_format += 1
            continue
        # Time filter
        if not filter_by_time(item, user_time):
            count_time += 1
            continue
        # Genre filter (only if user selected genres)
        item_genres = set([g.lower() for g in item.get('genres', [])])
        if user_genres and not (item_genres & user_genres):
            count_genre += 1
            continue
        # Mood filter (only if user selected moods and no genres selected)
        if not user_genres and mood_tags and not (item_genres & mood_tags):
            count_mood += 1
            continue
        filtered.append(item)
    logging.info(f"Filtered out {count_format} by format, {count_time} by time, {count_genre} by genre, {count_mood} by mood. {len(filtered)} items remain after filtering.")
    return filtered

@recommend_bp.route('/api/v1/recommend', methods=['POST'])
def recommend():
    token = session.get('plex_token') or os.environ.get('PLEX_TOKEN')
    server_name = session.get('plex_server_name')
    if not token:
        return jsonify({'error': 'Not connected to Plex'}), 401
    data = request.get_json() or {}
    # Pagination params
    try:
        page = int(request.args.get('page', 1))
        size = int(request.args.get('size', 3))
    except Exception:
        page = 1
        size = 3
    # UserInput: time, moods, genres, format, comfortMode, surprise
    user = {
        'time': data.get('time', '1_2h'),
        'moods': data.get('moods') or ([data.get('mood')] if data.get('mood') else []),
        'genres': data.get('genres') or [],
        'format': data.get('format', 'any'),
        'comfortMode': data.get('comfortMode', False),
        'surprise': data.get('surprise', False),
    }
    session_id = session.get('user_id') or session.sid if hasattr(session, 'sid') else request.cookies.get('session')
    # Check cache
    cached = get_cached_recommendations(str(session_id), user, page, size)
    if cached:
        logging.info(f"Returning cached recommendations for session {session_id}")
        return jsonify(cached), 200
    client = PlexClient()
    try:
        server = client.connect_via_token(token, server_name)
        # Optimize media loading
        if user['format'] == 'movie':
            items = server.library.section('Movies').all()
        elif user['format'] == 'show':
            items = server.library.section('TV Shows').all()
        else:
            items = server.library.all()
        logging.info(f"Fetched {len(items)} items from Plex library")
        for item in items:
            logging.info(f"Item: {getattr(item, 'title', 'N/A')}, type: {getattr(item, 'type', 'N/A')}, genres: {getattr(item, 'genres', [])}, duration: {getattr(item, 'duration', 0)}, viewCount: {getattr(item, 'viewCount', 0)}")
        media = []
        plex_base_url = server._baseurl if hasattr(server, '_baseurl') else None
        for item in items:
            if hasattr(item, 'type') and item.type in ('movie', 'show'):
                genres = [g.tag for g in getattr(item, 'genres', [])]
                duration_min = getattr(item, 'duration', 0) / 60000
                view_count = getattr(item, 'viewCount', 0)
                last_viewed = getattr(item, 'lastViewedAt', None)
                if last_viewed:
                    try:
                        last_viewed = datetime.fromtimestamp(last_viewed)
                    except Exception:
                        last_viewed = None
                poster_path = getattr(item, 'thumb', None)
                poster_url = None
                if poster_path and plex_base_url:
                    poster_url = f"{plex_base_url}{poster_path}?X-Plex-Token={token}"
                year = getattr(item, 'year', None)
                content_rating = getattr(item, 'contentRating', None)
                directors = [d.tag for d in getattr(item, 'directors', [])] if hasattr(item, 'directors') else []
                cast = [r.tag for r in getattr(item, 'roles', [])] if hasattr(item, 'roles') else []
                unwatched = view_count == 0
                media.append({
                    'title': getattr(item, 'title', ''),
                    'type': item.type,
                    'genres': genres,
                    'duration': duration_min,
                    'viewCount': view_count,
                    'lastViewedAt': last_viewed,
                    'rating': getattr(item, 'rating', None),
                    'summary': getattr(item, 'summary', ''),
                    'posterUrl': poster_url,
                    'year': year,
                    'contentRating': content_rating,
                    'directors': directors,
                    'cast': cast,
                    'unwatched': unwatched,
                })
        logging.info(f"Prepared {len(media)} media items for recommendation scoring.")
        filtered_media = filter_media(media, user)
        if not filtered_media:
            filtered_media = media
        feedback_map = get_feedback_map(session_id)
        liked, disliked = get_liked_disliked_attributes(session_id)
        suggestions = get_suggestions(filtered_media, user, feedback_map, liked, disliked, user.get('surprise', False), page)
        total = len(suggestions)
        start = (page - 1) * size
        end = start + size
        paged = suggestions[start:end]
        has_more = end < total
        result = {'recommendations': paged, 'hasMore': has_more}
        set_cached_recommendations(str(session_id), user, page, size, result)
        return jsonify(result), 200
    except AppError as e:
        return jsonify({'error': str(e)}), e.status_code
    except Exception as e:
        logging.exception("Error in /api/v1/recommend endpoint:")
        return jsonify({'error': str(e)}), 500

# Optionally, keep the old endpoint for backward compatibility
@recommend_bp.route('/api/recommend', methods=['POST'])
def recommend_legacy():
    return recommend()

@recommend_bp.route('/api/v1/feedback', methods=['POST'])
def feedback():
    data = request.get_json() or {}
    title = data.get('title')
    feedback_type = data.get('feedback')
    timestamp = data.get('timestamp')
    session_id = session.get('user_id') or session.sid if hasattr(session, 'sid') else request.cookies.get('session')
    db = get_session()
    try:
        # Find or create Media
        media = db.query(Media).filter_by(title=title).first()
        if not media:
            media = Media(title=title, plex_id=title, type='movie')  # fallback, ideally use plex_id
            db.add(media)
            db.commit()
            db.refresh(media)
        # Find or create Recommendation for this session/media
        rec = db.query(Recommendation).filter_by(media_id=media.id, group_size=session_id).first()
        if not rec:
            rec = Recommendation(media_id=media.id, group_size=session_id, timestamp=datetime.utcnow())
            db.add(rec)
            db.commit()
            db.refresh(rec)
        # Add Feedback
        fb = Feedback(recommendation_id=rec.id, timestamp=datetime.utcnow())
        if feedback_type == 'up':
            fb.rating = 5
            fb.would_watch_again = True
        elif feedback_type == 'down':
            fb.rating = 1
            fb.would_watch_again = False
        db.add(fb)
        db.commit()
        # Invalidate cache for this session
        invalidate_cache_for_session(str(session_id))
        return jsonify({'status': 'ok'}), 200
    except Exception as e:
        db.rollback()
        logging.exception("Error saving feedback:")
        return jsonify({'error': str(e)}), 500
    finally:
        db.close()
