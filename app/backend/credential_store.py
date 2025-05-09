import os
from cryptography.fernet import Fernet, InvalidToken
from app.backend.config import Config

class CredentialStore:
    """Encrypted file-based credential storage using Fernet symmetric encryption."""
    def __init__(self, filepath=None, key_env_var='CREDENTIAL_STORE_KEY'):
        if filepath is None:
            self.filepath = getattr(Config, 'CREDENTIAL_STORE_PATH', 'credentials.enc')
        else:
            self.filepath = filepath
        self.key = os.environ.get(key_env_var)
        if not self.key:
            raise ValueError(f"Encryption key not found in environment variable: {key_env_var}")
        self.fernet = Fernet(self.key.encode())

    @staticmethod
    def generate_key():
        """Generate a new Fernet key (base64-encoded). Store this securely!"""
        return Fernet.generate_key().decode()

    def save(self, data: dict):
        """Encrypt and save credentials to file."""
        import json
        plaintext = json.dumps(data).encode()
        ciphertext = self.fernet.encrypt(plaintext)
        with open(self.filepath, 'wb') as f:
            f.write(ciphertext)

    def load(self) -> dict:
        """Load and decrypt credentials from file."""
        import json
        if not os.path.exists(self.filepath):
            return {}
        with open(self.filepath, 'rb') as f:
            ciphertext = f.read()
        try:
            plaintext = self.fernet.decrypt(ciphertext)
            return json.loads(plaintext.decode())
        except InvalidToken:
            raise ValueError("Invalid encryption key or corrupted credential file.")

    def clear(self):
        """Delete the credential file."""
        if os.path.exists(self.filepath):
            os.remove(self.filepath) 