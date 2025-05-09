import threading
import time
import logging
from app.backend.plex_client import PlexClient
from app.backend.database import get_session, sync_plex_metadata
from app.backend.config import Config

logging.basicConfig(level=getattr(logging, Config.LOG_LEVEL, logging.INFO))
logger = logging.getLogger(__name__)

class PlexBackgroundSync:
    """Background processor for incremental Plex metadata updates."""
    def __init__(self, interval=3600):
        self.interval = interval  # seconds between syncs
        self.thread = None
        self.stop_event = threading.Event()
        self.last_update = 0

    def start(self):
        if self.thread and self.thread.is_alive():
            logger.info("Background sync already running.")
            return
        self.stop_event.clear()
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()
        logger.info("Started Plex background sync thread.")

    def stop(self):
        self.stop_event.set()
        if self.thread:
            self.thread.join()
        logger.info("Stopped Plex background sync thread.")

    def run(self):
        while not self.stop_event.is_set():
            try:
                self.incremental_sync()
            except Exception as e:
                logger.error(f"Background sync error: {e}")
            time.sleep(self.interval)

    def incremental_sync(self):
        """Detect and process only new/changed content since last update."""
        client = PlexClient()
        session = get_session()
        # Example: fetch all movies and shows, filter by updatedAt
        movies = client.get_all_movies()
        shows = client.get_all_shows()
        # Filter by updatedAt if available
        if self.last_update:
            movies = [m for m in movies if getattr(m, 'updatedAt', 0) > self.last_update]
            shows = [s for s in shows if getattr(s, 'updatedAt', 0) > self.last_update]
        sync_plex_metadata(session, movies, media_type='movie')
        sync_plex_metadata(session, shows, media_type='show')
        self.last_update = int(time.time())
        logger.info("Incremental sync complete.")

    def schedule_full_sync(self, interval=86400):
        """Stub for scheduling a full sync (e.g., daily)."""
        logger.info(f"Scheduled full sync every {interval} seconds (stub).")

    def monitor_jobs(self):
        """Stub for monitoring and alerting on background jobs."""
        logger.info("Monitoring not implemented.") 