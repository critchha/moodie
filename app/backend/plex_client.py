from plexapi.server import PlexServer
import os

class PlexClient:
    def connect_via_token(self, token, server_name=None):
        # Make PLEX_URL configurable via environment variable, default to your actual Plex server
        PLEX_URL = os.environ.get("PLEX_URL", "http://172.16.1.5:32400")
        plex = PlexServer(PLEX_URL, token)
        if server_name:
            # Optionally select a specific server by name, safely handle missing 'name' attribute
            for resource in plex.resources():
                if getattr(resource, 'name', None) == server_name:
                    return resource.connect()
        return plex 