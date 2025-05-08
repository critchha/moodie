from sqlalchemy import (
    create_engine, Column, Integer, String, Text, DateTime, Float, Boolean, ForeignKey
)
from sqlalchemy.orm import declarative_base, relationship, sessionmaker, scoped_session
from datetime import datetime
from sqlalchemy.exc import SQLAlchemyError
import logging

Base = declarative_base()

class Media(Base):
    """Stores Plex media metadata."""
    __tablename__ = 'media'
    id = Column(Integer, primary_key=True)
    plex_id = Column(String, unique=True, nullable=False)
    title = Column(String, nullable=False)
    type = Column(String)  # movie or show
    year = Column(Integer)
    genres = Column(String)  # comma-separated
    summary = Column(Text)
    duration = Column(Integer)  # in minutes
    last_updated = Column(DateTime, default=datetime.utcnow)
    # Relationship: one-to-many with Recommendation
    recommendations = relationship(
        'Recommendation', back_populates='media', cascade='all, delete-orphan'
    )

class Recommendation(Base):
    """Stores recommendation history."""
    __tablename__ = 'recommendations'
    id = Column(Integer, primary_key=True)
    media_id = Column(Integer, ForeignKey('media.id'))
    timestamp = Column(DateTime, default=datetime.utcnow)
    mood = Column(String)  # JSON string of mood inputs
    group_size = Column(String)  # solo, couple, group
    session_length = Column(String)  # short, medium, binge
    score = Column(Float)  # model prediction score
    # Relationship: many-to-one with Media, one-to-many with Feedback
    media = relationship('Media', back_populates='recommendations')
    feedback = relationship(
        'Feedback', back_populates='recommendation', cascade='all, delete-orphan'
    )

class Feedback(Base):
    """Stores user feedback on recommendations."""
    __tablename__ = 'feedback'
    id = Column(Integer, primary_key=True)
    recommendation_id = Column(Integer, ForeignKey('recommendations.id'))
    watched_completion = Column(Boolean)
    would_watch_again = Column(Boolean)
    rating = Column(Integer)  # 1-5 stars
    timestamp = Column(DateTime, default=datetime.utcnow)
    # Relationship: many-to-one with Recommendation
    recommendation = relationship('Recommendation', back_populates='feedback')

# Session factory
SessionLocal = scoped_session(sessionmaker(autocommit=False, autoflush=False, bind=None))

def get_session(engine=None):
    """Get a new SQLAlchemy session bound to the provided or default engine."""
    if engine is None:
        engine = get_engine()
    SessionLocal.configure(bind=engine)
    return SessionLocal()

# CRUD utility functions

def add_record(session, record):
    """Add a record to the session and commit."""
    try:
        session.add(record)
        session.commit()
        session.refresh(record)
        return record
    except Exception as e:
        session.rollback()
        print(f"Error adding record: {e}")
        raise

def get_record_by_id(session, model, record_id):
    """Get a record by primary key."""
    return session.query(model).get(record_id)

def get_all_records(session, model):
    """Get all records for a model."""
    return session.query(model).all()

def update_record(session, record):
    """Update a record and commit."""
    try:
        session.commit()
        session.refresh(record)
        return record
    except Exception as e:
        session.rollback()
        print(f"Error updating record: {e}")
        raise

def delete_record(session, record):
    """Delete a record and commit."""
    try:
        session.delete(record)
        session.commit()
    except Exception as e:
        session.rollback()
        print(f"Error deleting record: {e}")
        raise

# (Optional) Stubs for future migration, backup, and integrity checks
def backup_database(engine=None, backup_path='backup.db'):
    """Stub for backing up the database (to be implemented)."""
    print(f"Backup not implemented. Would back up to {backup_path}.")

def check_integrity(session):
    """Stub for checking database integrity (to be implemented)."""
    print("Integrity check not implemented.")

def get_engine(database_url=None):
    """Create a SQLAlchemy engine using the provided or default database URL."""
    if database_url is None:
        from app.backend.config import Config
        database_url = Config.SQLALCHEMY_DATABASE_URI
    try:
        engine = create_engine(database_url, echo=False, future=True)
        return engine
    except SQLAlchemyError as e:
        print(f"Error creating engine: {e}")
        raise

def init_db(engine=None):
    """Initialize the database and create all tables."""
    if engine is None:
        engine = get_engine()
    try:
        Base.metadata.create_all(engine)
        print("Database tables created successfully.")
    except SQLAlchemyError as e:
        print(f"Error initializing database: {e}")
        raise

def reset_db(engine=None):
    """Drop all tables and recreate them (for development/testing only)."""
    if engine is None:
        engine = get_engine()
    try:
        Base.metadata.drop_all(engine)
        Base.metadata.create_all(engine)
        print("Database reset successfully.")
    except SQLAlchemyError as e:
        print(f"Error resetting database: {e}")
        raise

def sync_plex_metadata(session, media_list, media_type='movie'):
    """
    Synchronize Plex metadata (movies or shows) with the database.
    - Upsert (insert or update) each media item.
    - Remove DB records not present in the latest Plex data.
    - Maintain relationship integrity.
    """
    logger = logging.getLogger(__name__)
    try:
        # Build a set of current Plex IDs
        plex_ids = set(item['plex_id'] for item in media_list if item.get('plex_id'))
        # Query all existing media of this type
        db_media = session.query(Media).filter_by(type=media_type).all()
        db_ids = set(m.plex_id for m in db_media)
        # Upsert each item
        for item in media_list:
            if not item.get('plex_id'):
                continue
            media = session.query(Media).filter_by(plex_id=item['plex_id']).first()
            if media:
                # Update existing
                for k, v in item.items():
                    setattr(media, k, v)
                logger.info(f"Updated {media_type}: {item['title']}")
            else:
                # Insert new
                media = Media(**item)
                session.add(media)
                logger.info(f"Inserted {media_type}: {item['title']}")
        # Remove DB records not in Plex
        for media in db_media:
            if media.plex_id not in plex_ids:
                logger.info(f"Deleting {media_type} not found in Plex: {media.title}")
                session.delete(media)
        session.commit()
        logger.info(f"Sync complete for {media_type}s. {len(media_list)} items processed.")
    except Exception as e:
        session.rollback()
        logger.error(f"Error during {media_type} sync: {e}")
        raise 