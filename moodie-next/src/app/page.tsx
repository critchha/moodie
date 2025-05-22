"use client";

import React, { useState, useEffect } from 'react';

const timeOptions = [
  { label: 'Less than an hour', value: 'under_1h' },
  { label: '1–2 hours', value: '1_2h' },
  { label: '2+ hours', value: '2plus' },
  { label: 'Open-ended / binge-friendly', value: 'open' },
];

const moodOptions = [
  { label: '😀 Light and funny', value: 'light_funny' },
  { label: '💥 Intense', value: 'intense' },
  { label: '😭 Emotional', value: 'emotional' },
  { label: '🎭 Dramatic', value: 'dramatic' },
];

const formatOptions = [
  { label: 'Movie', value: 'movie' },
  { label: 'TV show', value: 'show' },
  { label: 'No, stick to my vibe', value: 'any' },
];

const genreOptions = [
  { label: 'Action', value: 'action' },
  { label: 'Comedy', value: 'comedy' },
  { label: 'Drama', value: 'drama' },
  { label: 'Family', value: 'family' },
  { label: 'Animation', value: 'animation' },
  { label: 'Thriller', value: 'thriller' },
  { label: 'Crime', value: 'crime' },
  { label: 'Romance', value: 'romance' },
  { label: 'Biography', value: 'biography' },
  { label: 'Musical', value: 'musical' },
  { label: 'Mystery', value: 'mystery' },
  { label: 'Historical', value: 'historical' },
  // Add more as needed
];

function parseMoodVibe(moodValue: string) {
  // e.g., 'happy-funny' => { mood: 'happy', vibe: 'funny' }
  const [mood, vibe] = moodValue.split('-');
  return { mood, vibe };
}

function mapTimeToSession(time: string) {
  if (time === '30-60') return 'short';
  if (time === '120+') return 'long';
  return undefined;
}

const lightBlueClasses = 'bg-blue-300 text-blue-900';
const defaultTime = '1_2h';
const defaultMood = 'light_funny';
const defaultFormat = 'any';
const defaultSurprise = false;
const defaultComfort = false;

// Add a helper to trigger animation on selection
const getPopClass = (selected: boolean) => selected ? 'animate-pop' : '';

function App() {
  const [time, setTime] = useState(defaultTime);
  const [selectedMoods, setSelectedMoods] = useState<string[]>([defaultMood]);
  const [format, setFormat] = useState(defaultFormat);
  const [surprise, setSurprise] = useState(defaultSurprise);
  const [comfort, setComfort] = useState(defaultComfort);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [recommendations, setRecommendations] = useState<any[]>([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  // Plex connection state
  const [plexConnected, setPlexConnected] = useState(false);
  const [showPlexForm, setShowPlexForm] = useState(false);
  const getInitialPlexToken = () => {
    if (typeof window !== 'undefined') {
      const savedToken = localStorage.getItem('plexToken');
      if (savedToken) return savedToken;
    }
    return process.env.NEXT_PUBLIC_PLEX_TOKEN || '';
  };
  const [plexToken, setPlexToken] = useState(getInitialPlexToken());
  const [plexServerName, setPlexServerName] = useState('');
  const [plexError, setPlexError] = useState<string | null>(null);
  const [selectedGenres, setSelectedGenres] = useState<string[]>([]);
  const [feedbackGiven, setFeedbackGiven] = useState<{ [title: string]: 'up' | 'down' }>({});

  // On mount, check Plex connection status and localStorage/env for token
  useEffect(() => {
    fetch('/api/v1/plex/status', { credentials: 'include' })
      .then((res) => res.json())
      .then((data) => {
        setPlexConnected(data.connected);
      });
    // Prefill plexToken from localStorage or env if not already set
    if (!plexToken) {
      const savedToken = localStorage.getItem('plexToken');
      if (savedToken) {
        setPlexToken(savedToken);
      } else if (process.env.NEXT_PUBLIC_PLEX_TOKEN) {
        setPlexToken(process.env.NEXT_PUBLIC_PLEX_TOKEN);
      }
    }
  }, []);

  // Debug: log recommendations when they change
  useEffect(() => {
    if (recommendations.length > 0) {
      console.log('[DEBUG] Recommendations to render:', recommendations);
    }
  }, [recommendations]);

  const handleGenreChange = (genre: string) => {
    setSelectedGenres(prev =>
      prev.includes(genre) ? prev.filter(g => g !== genre) : [...prev, genre]
    );
  };

  const handleMoodChange = (mood: string) => {
    setSelectedMoods(prev =>
      prev.includes(mood) ? prev.filter(m => m !== mood) : [...prev, mood]
    );
  };

  const handleSubmit = async (
    e?: React.FormEvent,
    override?: { time?: string; mood?: string | string[]; format?: string; surprise?: boolean; comfort?: boolean; genres?: string[] }
  ) => {
    if (e) e.preventDefault();
    setError(null);
    setRecommendations([]);
    setPage(1);
    setHasMore(false);
    setLoading(true);
    const currentTime = override?.time ?? time;
    const currentMoods = override?.mood ?? selectedMoods;
    const currentFormat = override?.format ?? format;
    const currentSurprise = override?.surprise ?? surprise;
    const currentComfort = override?.comfort ?? comfort;
    const currentGenres = override?.genres ?? selectedGenres;
    const payload = {
      time: currentTime,
      moods: currentMoods,
      format: currentFormat,
      comfortMode: currentComfort,
      surprise: currentSurprise,
      genres: currentGenres,
    };
    try {
      const res = await fetch(`/api/v1/recommend?page=1&size=3`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        throw new Error(`Error: ${res.status}`);
      }
      const data = await res.json();
      let recs: any[] = [];
      if (Array.isArray(data)) {
        recs = data;
      } else if (Array.isArray(data.recommendations)) {
        recs = data.recommendations;
      }
      recs = recs.map(r => ({ ...r, source: 'primary' }));
      setRecommendations(recs);
      setHasMore(!!data.hasMore);
      setPage(1);
      // Do NOT reset selections here; only reset on explicit reset
    } catch (err: any) {
      setError(err.message || 'Failed to fetch recommendations');
    } finally {
      setLoading(false);
    }
  };

  const handleLoadMore = async () => {
    setLoading(true);
    const nextPage = page + 1;
    const payload = {
      time,
      moods: selectedMoods,
      format,
      comfortMode: comfort,
      surprise,
      genres: selectedGenres,
    };
    try {
      const res = await fetch(`/api/v1/recommend?page=${nextPage}&size=3`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        throw new Error(`Error: ${res.status}`);
      }
      const data = await res.json();
      let recs: any[] = [];
      if (Array.isArray(data)) {
        recs = data;
      } else if (Array.isArray(data.recommendations)) {
        recs = data.recommendations;
      }
      recs = recs.map(r => ({ ...r, source: 'primary' }));
      setRecommendations(prev => {
        const all = [...prev, ...recs];
        const seen = new Set();
        return all.filter(rec => {
          if (seen.has(rec.title)) return false;
          seen.add(rec.title);
          return true;
        });
      });
      setHasMore(!!data.hasMore);
      setPage(nextPage);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch recommendations');
    } finally {
      setLoading(false);
    }
  };

  const handleFeedback = async (title: string, feedback: 'up' | 'down') => {
    setFeedbackGiven(prev => ({ ...prev, [title]: feedback }));
    try {
      await fetch('/api/v1/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          title,
          feedback,
          timestamp: new Date().toISOString(),
        }),
      });
    } catch (err) {
      // Optionally handle error
    }
  };

  // Add a simple spinner component
  function Spinner() {
    return (
      <div className="flex justify-center items-center py-10">
        <svg className="animate-spin h-8 w-8 text-accent-blue" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8z" />
        </svg>
      </div>
    );
  }

  // Add a skeleton card component
  function SkeletonCard() {
    return (
      <li className="p-4 rounded-xl bg-gray-800 border border-gray-600 shadow flex gap-4 animate-pulse">
        <div className="w-20 h-28 bg-gray-700 rounded-lg" />
        <div className="flex-1 space-y-2">
          <div className="h-6 bg-gray-700 rounded w-1/2" />
          <div className="h-4 bg-gray-700 rounded w-1/3" />
          <div className="h-4 bg-gray-700 rounded w-1/4" />
          <div className="h-4 bg-gray-700 rounded w-2/3" />
          <div className="h-4 bg-gray-700 rounded w-1/2" />
        </div>
      </li>
    );
  }

  // Only reset selections when the user presses Reset Options
  const handleResetOptions = () => {
    setTime('');
    setSelectedMoods([]);
    setFormat('');
    setSurprise(false);
    setComfort(false);
    setSelectedGenres([]);
  };

  return (
    <div className="min-h-screen bg-rich-black text-white px-2 sm:px-4 md:px-6 py-6 md:py-10 flex flex-col items-center justify-center font-inter">
      <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-2 text-center">What's your vibe tonight?</h1>
      <p className="text-muted-gray mb-6 md:mb-10 text-center text-base md:text-lg">Let Moodie help you decide what to watch.</p>

      {/*
      // The Connect Plex button is commented out because the Plex token is now provided at build time via env and does not require user input.
      {!plexConnected ? (
        <>
          <button
            className="mb-4 px-4 py-2 bg-accent-blue text-white rounded"
            onClick={() => setShowPlexForm(true)}
          >
            Connect Plex
          </button>
          {showPlexForm && (
            <form
              className="mb-4 flex flex-col gap-2"
              onSubmit={async (e) => {
                e.preventDefault();
                setPlexError(null);
                try {
                  const res = await fetch('/api/v1/plex/connect', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    credentials: 'include',
                    body: JSON.stringify({ token: plexToken, server_name: plexServerName || undefined }),
                  });
                  if (!res.ok) {
                    const data = await res.json();
                    throw new Error(data.error || 'Failed to connect to Plex');
                  }
                  setPlexConnected(true);
                  setShowPlexForm(false);
                  localStorage.setItem('plexToken', plexToken); // Save token to localStorage
                  setPlexToken('');
                  setPlexServerName('');
                } catch (err: any) {
                  setPlexError(err.message || 'Failed to connect to Plex');
                }
              }}
            >
              <input
                type="text"
                placeholder="Plex Token"
                value={plexToken}
                onChange={e => setPlexToken(e.target.value)}
                className="p-2 rounded border"
                required
              />
              <input
                type="text"
                placeholder="Server Name (optional)"
                value={plexServerName}
                onChange={e => setPlexServerName(e.target.value)}
                className="p-2 rounded border"
              />
              <button type="submit" className="px-4 py-2 bg-accent-blue text-white rounded">
                Connect
              </button>
              {plexError && <div className="text-red-400">{plexError}</div>}
            </form>
          )}
        </>
      ) : (
        <div className="mb-4 text-green-500">Plex Connected!</div>
      )
      */}
      {plexConnected && (
        <div className="mb-4 text-green-500">Plex Connected!</div>
      )}

      <div className="w-full max-w-lg md:max-w-2xl space-y-4 md:space-y-6">
        {/* Time Selector */}
        <div>
          <label className="block text-base md:text-lg font-semibold mb-2">Time</label>
          <div className="flex flex-wrap gap-1 md:gap-2">
            {timeOptions.map(opt => (
              <button
                key={opt.value}
                type="button"
                onClick={() => setTime(opt.value)}
                className={`px-3 py-2 md:px-4 md:py-2 rounded-xl font-medium transition text-sm md:text-base
                  ${time === opt.value && time !== '' ? lightBlueClasses + ' ' + getPopClass(true) : 'bg-card-bg text-gray-300 hover:bg-accent-blue hover:text-white'}`}
                aria-pressed={time === opt.value}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {/* Mood Selector (multi-select) */}
        <div>
          <label className="block text-base md:text-lg font-semibold mb-2">Mood</label>
          <div className="flex flex-wrap gap-1 md:gap-2">
            {moodOptions.map(opt => (
              <button
                key={opt.value}
                type="button"
                onClick={() => handleMoodChange(opt.value)}
                className={`px-3 py-2 md:px-4 md:py-2 rounded-xl font-medium transition text-sm md:text-base
                  ${selectedMoods.length > 0 && selectedMoods.includes(opt.value) ? lightBlueClasses + ' ' + getPopClass(true) : 'bg-card-bg text-gray-300 hover:bg-accent-blue hover:text-white'}`}
                aria-pressed={selectedMoods.includes(opt.value)}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {/* Genre Selector (multi-select) */}
        <div>
          <label className="block text-base md:text-lg font-semibold mb-2">Genres</label>
          <div className="flex flex-wrap gap-1 md:gap-2">
            {genreOptions.map(opt => (
              <button
                key={opt.value}
                type="button"
                onClick={() => handleGenreChange(opt.value)}
                className={`px-3 py-2 md:px-4 md:py-2 rounded-xl font-medium transition text-sm md:text-base
                  ${selectedGenres.length > 0 && selectedGenres.includes(opt.value) ? lightBlueClasses + ' ' + getPopClass(true) : 'bg-card-bg text-gray-300 hover:bg-accent-blue hover:text-white'}`}
                aria-pressed={selectedGenres.includes(opt.value)}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {/* Format + Comfort */}
        <div className="flex flex-col items-center mb-2">
          <label className="block text-base md:text-lg font-semibold mb-2 text-left w-full">Format</label>
          <div className="flex flex-col sm:flex-row gap-2 md:gap-4 justify-center w-full mb-2 md:mb-4">
            {formatOptions.map(opt => (
              <button
                key={opt.value}
                type="button"
                onClick={() => setFormat(opt.value)}
                className={`flex flex-col items-center justify-center w-full sm:w-40 md:w-48 h-24 md:h-40 px-3 py-2 md:px-6 md:py-3 rounded-xl font-medium transition border-2 text-base md:text-lg
                  ${format === opt.value && format !== '' ? lightBlueClasses + ' border-blue-300 shadow-lg ' + getPopClass(true) : 'bg-card-bg text-gray-300 border-transparent hover:bg-accent-blue hover:text-white'}`}
                aria-pressed={format === opt.value}
              >
                {opt.value === 'movie' && <span className="text-2xl md:text-3xl mb-1 md:mb-2">🎬</span>}
                {opt.value === 'tv' && <span className="text-2xl md:text-3xl mb-1 md:mb-2">📺</span>}
                <span className="text-center">{opt.label}</span>
              </button>
            ))}
          </div>
          {/* Checkboxes */}
          <div className="flex items-center space-x-2 md:space-x-3 mb-2 w-full">
            <input
              id="surprise"
              type="checkbox"
              className="form-checkbox h-5 w-5 text-accent-blue rounded bg-card-bg border-muted-gray focus:ring-2 focus:ring-accent-blue"
              checked={surprise}
              onChange={e => setSurprise(e.target.checked)}
            />
            <label htmlFor="surprise" className="text-gray-300 text-xs md:text-sm font-medium">Surprise me with something different</label>
          </div>
          <div className="flex items-center gap-2 md:gap-3 w-full mb-2">
            <input
              type="checkbox"
              id="comfort"
              className="form-checkbox h-5 w-5 text-accent-blue rounded bg-card-bg border-muted-gray focus:ring-2 focus:ring-accent-blue"
              checked={comfort}
              onChange={e => setComfort(e.target.checked)}
            />
            <label htmlFor="comfort" className="text-gray-300 font-medium text-xs md:text-base">
              Comfort
              <span className="text-xs md:text-sm block text-muted-gray">Includes your favorite rewatches</span>
            </label>
          </div>
        </div>

        {/* Submit Button Row */}
        <div className="pt-2 md:pt-4 flex flex-col md:flex-row gap-2 md:gap-4">
          <button
            type="submit"
            className="w-full py-3 text-base md:text-lg font-semibold rounded-xl bg-accent-blue hover:bg-blue-500 transition text-white shadow-card"
            disabled={loading}
            onClick={handleSubmit}
          >
            {loading ? 'Loading...' : 'Get Recommendations'}
          </button>
          <button
            type="button"
            className="w-full py-3 text-base md:text-lg font-semibold rounded-xl bg-gray-700 hover:bg-gray-500 transition text-white shadow-card"
            onClick={handleResetOptions}
            disabled={loading}
          >
            Reset Options
          </button>
        </div>
      </div>

      {/* Recommendations Section */}
      {loading && (
        <div className="mt-8 md:mt-10 w-full max-w-lg md:max-w-2xl">
          <Spinner />
          <ul className="space-y-4">
            {[1, 2, 3].map(i => <SkeletonCard key={i} />)}
          </ul>
        </div>
      )}
      {!loading && error && (
        <div className="mt-8 md:mt-10 w-full max-w-lg md:max-w-2xl text-center">
          <div className="text-red-400 text-lg font-semibold mb-2">{error}</div>
          <button
            className="px-4 py-2 bg-accent-blue text-white rounded font-semibold"
            onClick={() => handleSubmit()}
          >
            Retry
          </button>
        </div>
      )}
      {!loading && !error && recommendations.length > 0 && (
        <div className="mt-8 md:mt-10 w-full max-w-lg md:max-w-2xl">
          <h2 className="text-xl md:text-2xl font-bold mb-4">Recommendations</h2>
          <ul className="space-y-4">
            {recommendations.map((rec, idx) => (
              <li key={rec.title + idx} className="p-3 md:p-4 rounded-xl bg-gray-800 border border-gray-600 shadow flex flex-col sm:flex-row gap-3 md:gap-4">
                {/* Poster thumbnail */}
                {rec.posterUrl && (
                  <img
                    src={rec.posterUrl}
                    alt={rec.title + ' poster'}
                    className="w-28 h-40 md:w-20 md:h-28 object-cover rounded-lg flex-shrink-0 border border-gray-700 mx-auto sm:mx-0"
                  />
                )}
                <div className="flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <div className="text-lg md:text-xl font-semibold">{rec.title}</div>
                    {rec.year && <span className="px-2 py-1 rounded text-xs font-bold bg-blue-900 text-blue-200">{rec.year}</span>}
                    {rec.contentRating && <span className="px-2 py-1 rounded text-xs font-bold bg-purple-900 text-purple-200">{rec.contentRating}</span>}
                    {rec.unwatched && <span className="px-2 py-1 rounded text-xs font-bold bg-yellow-700 text-yellow-100">Unwatched</span>}
                    <span className={`px-2 py-1 rounded text-xs font-bold ${rec.source === 'fallback' ? 'bg-yellow-600 text-white' : 'bg-green-700 text-white'}`}>{rec.source === 'fallback' ? 'Fallback' : 'Primary'}</span>
                  </div>
                  {/* Genre badges */}
                  <div className="flex flex-wrap gap-2 mt-1">
                    {Array.isArray(rec.genres) && rec.genres.map((g: string) => (
                      <span key={g} className="px-2 py-0.5 rounded text-xs bg-gray-700 text-gray-200">{g}</span>
                    ))}
                  </div>
                  {/* Director(s) */}
                  {Array.isArray(rec.directors) && rec.directors.length > 0 && (
                    <div className="text-xs md:text-sm text-gray-400 mt-1">Director: {rec.directors.join(', ')}</div>
                  )}
                  {/* Cast */}
                  {Array.isArray(rec.cast) && rec.cast.length > 0 && (
                    <div className="text-xs md:text-sm text-gray-400 mt-1">Cast: {rec.cast.slice(0, 4).join(', ')}{rec.cast.length > 4 ? ', ...' : ''}</div>
                  )}
                  <div className="text-xs md:text-sm text-gray-400 capitalize mt-1">{rec.type}</div>
                  <div className="text-xs md:text-sm text-gray-400">
                    {rec.rating && <>⭐ {rec.rating} &nbsp;</>}
                    {rec.duration && (
                      <>
                        ⏱️ {Math.round(rec.duration)} min
                      </>
                    )}
                  </div>
                  <div className="mt-2 text-sm md:text-base">{rec.summary}</div>
                  {/* Feedback buttons */}
                  <div className="mt-3 flex gap-3 items-center">
                    <button
                      aria-label="Thumbs up"
                      className={`px-3 py-2 rounded-full border-2 text-lg transition ${feedbackGiven[rec.title] === 'up' ? 'bg-green-600 border-green-400 text-white' : 'bg-gray-700 border-gray-500 text-gray-200 hover:bg-green-700 hover:border-green-400'}`}
                      onClick={() => handleFeedback(rec.title, 'up')}
                      disabled={!!feedbackGiven[rec.title]}
                    >
                      👍
                    </button>
                    <button
                      aria-label="Thumbs down"
                      className={`px-3 py-2 rounded-full border-2 text-lg transition ${feedbackGiven[rec.title] === 'down' ? 'bg-red-600 border-red-400 text-white' : 'bg-gray-700 border-gray-500 text-gray-200 hover:bg-red-700 hover:border-red-400'}`}
                      onClick={() => handleFeedback(rec.title, 'down')}
                      disabled={!!feedbackGiven[rec.title]}
                    >
                      👎
                    </button>
                    {feedbackGiven[rec.title] && (
                      <span className="ml-2 text-xs md:text-sm text-gray-300">Thanks for your feedback!</span>
                    )}
                  </div>
                </div>
              </li>
            ))}
          </ul>
          {hasMore && (
            <div className="flex justify-center mt-4">
              <button
                className="px-6 py-2 rounded-xl bg-accent-blue text-white font-semibold text-base md:text-lg hover:bg-blue-500 transition shadow-card"
                onClick={handleLoadMore}
                disabled={loading}
              >
                {loading ? 'Loading...' : 'Load More'}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default App;
