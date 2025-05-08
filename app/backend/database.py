from sqlalchemy import (
    create_engine, Column, Integer, String, Text, DateTime, Float, Boolean, ForeignKey
)
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime

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
    recommendations = relationship('Recommendation', back_populates='media')

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
    feedback = relationship('Feedback', back_populates='recommendation')

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