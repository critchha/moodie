from plexapi.myplex import MyPlexAccount
from plexapi.server import PlexServer
from app.backend.errors import AppError

class PlexClient:
    """Handles authentication and connection to Plex Media Server."""
    def __init__(self):
        self.server = None
        self.account = None

    def connect_via_token(self, token, server_name=None, timeout=10):
        """Connect to Plex server using an auth token. Optionally specify server name."""
        try:
            self.account = MyPlexAccount(token=token, timeout=timeout)
            if server_name:
                resource = self.account.resource(server_name)
                if not resource:
                    raise AppError(f"Server '{server_name}' not found in Plex account.", status_code=404)
                self.server = resource.connect()
            else:
                resources = self.account.resources()
                if not resources:
                    raise AppError("No Plex servers found for this account.", status_code=404)
                self.server = resources[0].connect()
            return self.server
        except Exception as e:
            raise AppError(f"Failed to connect to Plex: {e}", status_code=401)

    def validate_token(self, token, timeout=10):
        """Validate a Plex token by attempting to fetch account info."""
        try:
            account = MyPlexAccount(token=token, timeout=timeout)
            # If this succeeds, token is valid
            return True
        except Exception:
            return False

    # Stub for future token refresh logic
    def refresh_token(self):
        """Stub for token refresh (not typically needed for Plex)."""
        raise NotImplementedError("Token refresh not implemented for Plex.")

    def connect_direct(self, baseurl, token, timeout=10):
        """Connect directly to a Plex server with URL and token."""
        try:
            self.server = PlexServer(baseurl, token, timeout=timeout)
            return self.server
        except Exception as e:
            raise AppError(f"Failed to connect directly to Plex server: {e}", status_code=401)

    def discover_servers(self):
        """Stub for automatic server discovery on local networks (to be implemented)."""
        raise NotImplementedError("Automatic server discovery not implemented.")

    def prioritize_connection(self, servers):
        """Stub for connection prioritization logic (local before remote)."""
        # Example: sort servers by local/remote, prefer local
        raise NotImplementedError("Connection prioritization not implemented.") 