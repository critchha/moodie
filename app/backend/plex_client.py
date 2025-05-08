from plexapi.myplex import MyPlexAccount
from plexapi.server import PlexServer
from app.backend.errors import AppError
import logging
import threading
import time

logger = logging.getLogger(__name__)

class PlexClient:
    """Handles authentication and connection to Plex Media Server.

    Singleton pattern ensures only one instance per process.
    Includes logging and basic rate limiting for API calls.

    Troubleshooting:
    - Ensure your Plex token is valid and not expired.
    - Check network connectivity to your Plex server.
    - Review logs for authentication or connection errors.
    - For persistent issues, try clearing stored credentials and re-authenticating.
    """
    _instance = None
    _lock = threading.Lock()
    _last_api_call = 0
    _rate_limit_seconds = 2  # Minimum seconds between API calls

    def __new__(cls, *args, **kwargs):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
        return cls._instance

    def _rate_limit(self):
        now = time.time()
        elapsed = now - self._last_api_call
        if elapsed < self._rate_limit_seconds:
            logger.info(f"Rate limiting: sleeping for {self._rate_limit_seconds - elapsed:.2f} seconds")
            time.sleep(self._rate_limit_seconds - elapsed)
        self._last_api_call = time.time()

    def __init__(self):
        self.server = None
        self.account = None

    def connect_via_token(self, token, server_name=None, timeout=10):
        """Connect to Plex server using an auth token. Optionally specify server name."""
        self._rate_limit()
        try:
            self.account = MyPlexAccount(token=token, timeout=timeout)
            if server_name:
                resource = self.account.resource(server_name)
                if not resource:
                    logger.error(f"Server '{server_name}' not found in Plex account.")
                    raise AppError(f"Server '{server_name}' not found in Plex account.", status_code=404)
                self.server = resource.connect()
            else:
                resources = self.account.resources()
                if not resources:
                    logger.error("No Plex servers found for this account.")
                    raise AppError("No Plex servers found for this account.", status_code=404)
                self.server = resources[0].connect()
            return self.server
        except Exception as e:
            logger.error(f"Failed to connect to Plex: {e}")
            raise AppError(f"Failed to connect to Plex: {e}", status_code=401)

    def validate_token(self, token, timeout=10):
        """Validate a Plex token by attempting to fetch account info."""
        self._rate_limit()
        try:
            account = MyPlexAccount(token=token, timeout=timeout)
            return True
        except Exception as e:
            logger.warning(f"Token validation failed: {e}")
            return False

    # Stub for future token refresh logic
    def refresh_token(self):
        """Stub for token refresh (not typically needed for Plex)."""
        raise NotImplementedError("Token refresh not implemented for Plex.")

    def connect_direct(self, baseurl, token, timeout=10):
        """Connect directly to a Plex server with URL and token."""
        self._rate_limit()
        try:
            self.server = PlexServer(baseurl, token, timeout=timeout)
            return self.server
        except Exception as e:
            logger.error(f"Failed to connect directly to Plex server: {e}")
            raise AppError(f"Failed to connect directly to Plex server: {e}", status_code=401)

    def discover_servers(self):
        """Stub for automatic server discovery on local networks (to be implemented)."""
        raise NotImplementedError("Automatic server discovery not implemented.")

    def prioritize_connection(self, servers):
        """Stub for connection prioritization logic (local before remote)."""
        # Example: sort servers by local/remote, prefer local
        raise NotImplementedError("Connection prioritization not implemented.")

    def check_connection_status(self):
        """Check if the current Plex server connection is alive."""
        if not self.server:
            return False
        try:
            # Try to fetch server info as a health check
            _ = self.server.friendlyName
            return True
        except Exception:
            return False

    def reconnect(self, *args, **kwargs):
        """Attempt to reconnect to the Plex server using the last known credentials."""
        # This is a stub; in a real implementation, store last used method/params
        raise NotImplementedError("Automatic reconnection logic not implemented.")

    def start_status_monitoring(self, interval=60):
        """Stub for starting a background thread to monitor connection status."""
        # Would use threading/timers in a real implementation
        raise NotImplementedError("Status monitoring not implemented.")

    def on_status_change(self, callback):
        """Stub for registering a callback for connection status changes."""
        raise NotImplementedError("Event system for status changes not implemented.")

    def get_all_movies(self, section_name='Movies'):
        """Fetch all movies from the specified Plex library section, handling pagination."""
        if not self.server:
            logger.error("Not connected to Plex server.")
            raise AppError("Not connected to Plex server.", status_code=400)
        try:
            section = self.server.library.section(section_name)
            # PlexAPI handles pagination internally for .all(), but we can chunk if needed
            movies = section.all()
            logger.info(f"Fetched {len(movies)} movies from section '{section_name}'.")
            return [self.extract_movie_metadata(movie) for movie in movies]
        except Exception as e:
            logger.error(f"Failed to fetch movies: {e}")
            raise AppError(f"Failed to fetch movies: {e}", status_code=500)

    def extract_movie_metadata(self, movie):
        """Extract and normalize metadata from a Plex movie item for database storage."""
        try:
            genres = [genre.tag for genre in getattr(movie, 'genres', [])]
            directors = [d.tag for d in getattr(movie, 'directors', [])]
            writers = [w.tag for w in getattr(movie, 'writers', [])]
            cast = [a.tag for a in getattr(movie, 'actors', [])]
            poster = movie.posterUrl if hasattr(movie, 'posterUrl') else None
            backdrop = movie.art if hasattr(movie, 'art') else None
            return {
                'plex_id': movie.ratingKey,
                'title': movie.title,
                'type': 'movie',
                'year': getattr(movie, 'year', None),
                'genres': ','.join(genres),
                'summary': getattr(movie, 'summary', None),
                'duration': getattr(movie, 'duration', None) // 60000 if getattr(movie, 'duration', None) else None,
                'directors': ','.join(directors),
                'writers': ','.join(writers),
                'cast': ','.join(cast),
                'poster': poster,
                'backdrop': backdrop,
            }
        except Exception as e:
            logger.warning(f"Failed to extract metadata for movie: {e}")
            return {}

    def get_all_shows(self, section_name='TV Shows'):
        """Fetch all TV shows from the specified Plex library section, including seasons and episodes."""
        if not self.server:
            logger.error("Not connected to Plex server.")
            raise AppError("Not connected to Plex server.", status_code=400)
        try:
            section = self.server.library.section(section_name)
            shows = section.all()
            logger.info(f"Fetched {len(shows)} TV shows from section '{section_name}'.")
            return [self.extract_show_metadata(show) for show in shows]
        except Exception as e:
            logger.error(f"Failed to fetch TV shows: {e}")
            raise AppError(f"Failed to fetch TV shows: {e}", status_code=500)

    def extract_show_metadata(self, show):
        """Extract and normalize metadata from a Plex show item, including seasons and episodes."""
        try:
            genres = [genre.tag for genre in getattr(show, 'genres', [])]
            cast = [a.tag for a in getattr(show, 'actors', [])]
            poster = show.posterUrl if hasattr(show, 'posterUrl') else None
            backdrop = show.art if hasattr(show, 'art') else None
            # Extract seasons and episodes
            seasons = []
            for season in getattr(show, 'seasons', lambda: [])().values():
                episodes = []
                for episode in getattr(season, 'episodes', lambda: [])().values():
                    episodes.append({
                        'plex_id': episode.ratingKey,
                        'title': episode.title,
                        'season_number': getattr(season, 'index', None),
                        'episode_number': getattr(episode, 'index', None),
                        'summary': getattr(episode, 'summary', None),
                        'duration': getattr(episode, 'duration', None) // 60000 if getattr(episode, 'duration', None) else None,
                        'air_date': getattr(episode, 'originallyAvailableAt', None),
                    })
                seasons.append({
                    'plex_id': season.ratingKey,
                    'title': season.title,
                    'season_number': getattr(season, 'index', None),
                    'episodes': episodes
                })
            return {
                'plex_id': show.ratingKey,
                'title': show.title,
                'type': 'show',
                'year': getattr(show, 'year', None),
                'genres': ','.join(genres),
                'summary': getattr(show, 'summary', None),
                'cast': ','.join(cast),
                'poster': poster,
                'backdrop': backdrop,
                'seasons': seasons
            }
        except Exception as e:
            logger.warning(f"Failed to extract metadata for show: {e}")
            return {} 