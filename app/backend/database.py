from sqlalchemy import (
    create_engine, Column, Integer, String, Text, DateTime, Float, Boolean, ForeignKey
)
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime
from sqlalchemy.exc import SQLAlchemyError

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