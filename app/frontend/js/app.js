// app/frontend/js/app.js

// Utility: Show/hide sections with animation
function showSection(id) {
  document.querySelectorAll('.section').forEach(sec => {
    if (sec.id === id) {
      sec.classList.remove('hidden');
      sec.classList.add('animate-fadeIn');
      sec.style.opacity = 1;
      sec.style.transform = 'translateY(0)';
    } else {
      sec.classList.add('hidden');
      sec.classList.remove('animate-fadeIn');
      sec.style.opacity = 0;
      sec.style.transform = 'translateY(20px)';
    }
  });
}

// Example: API call template
async function apiRequest(endpoint, method = 'GET', data = null) {
  try {
    const options = { method, headers: { 'Content-Type': 'application/json' } };
    if (data) options.body = JSON.stringify(data);
    const res = await fetch(endpoint, options);
    if (!res.ok) throw new Error(await res.text());
    return await res.json();
  } catch (err) {
    showError(err.message);
    throw err;
  }
}

// Example: Show error message in aria-live region
function showError(msg) {
  clearMessages();
  let el = document.createElement('div');
  el.id = 'error-message';
  el.className = 'error-message bg-red-50 border border-red-400 text-red-700 rounded-lg px-4 py-3 mb-4 flex items-center gap-2 shadow-sm animate-fadeIn';
  el.setAttribute('role', 'alert');
  el.innerHTML = '<span class="message-icon" aria-hidden="true">&#9888;&#65039;</span>' + msg;
  document.getElementById('form-messages').appendChild(el);
}

// Show success message in aria-live region
function showSuccess(msg) {
  clearMessages();
  let el = document.createElement('div');
  el.className = 'success-message bg-teal-50 border border-teal-400 text-teal-700 rounded-lg px-4 py-3 mb-4 flex items-center gap-2 shadow-sm animate-fadeIn';
  el.setAttribute('role', 'status');
  el.innerHTML = '<span class="message-icon" aria-hidden="true">&#10003;</span>' + msg;
  document.getElementById('form-messages').appendChild(el);
}

// Clear all feedback messages
function clearMessages() {
  const region = document.getElementById('form-messages');
  if (region) region.innerHTML = '';
}

// Example: Loading indicator
function showLoading() {
  let el = document.getElementById('loading');
  if (!el) {
    el = document.createElement('div');
    el.id = 'loading';
    el.textContent = 'Loading...';
    el.style.textAlign = 'center';
    document.querySelector('main').prepend(el);
  }
}
function hideLoading() {
  const el = document.getElementById('loading');
  if (el) el.remove();
}

// Example: Initial UI state
window.addEventListener('DOMContentLoaded', () => {
  clearMessages();
  hideLoading();
  showSection('mood-form');
  addButtonPressAnimation();
  // Add more initialization as needed
  document.querySelectorAll('.tooltip').forEach(tooltip => {
    // Show on mouseenter/focus
    tooltip.addEventListener('mouseenter', () => showTooltip(tooltip));
    tooltip.addEventListener('focus', () => showTooltip(tooltip));
    // Hide on mouseleave/blur
    tooltip.addEventListener('mouseleave', hideAllTooltips);
    tooltip.addEventListener('blur', hideAllTooltips);
    // Hide on Escape key
    tooltip.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        hideAllTooltips();
        tooltip.blur();
      }
    });
  });
  updatePlexStatus();
  const plexStatus = document.getElementById('plex-status');
  if (plexStatus) {
    plexStatus.style.cursor = 'pointer';
    plexStatus.title = 'Click to connect to Plex';
    plexStatus.addEventListener('click', connectToPlex);
  }
  const connectPlexBtn = document.getElementById('connect-plex-btn');
  if (connectPlexBtn) {
    connectPlexBtn.addEventListener('click', connectToPlex);
  }
});

// Mood questionnaire form validation
const moodForm = document.getElementById('mood-questionnaire');
if (moodForm) {
  moodForm.addEventListener('submit', async function (e) {
    clearMessages();
    let valid = true;
    // Check required radio groups
    ['mood', 'vibe', 'group', 'session'].forEach(name => {
      const checked = moodForm.querySelector(`input[name="${name}"]:checked`);
      if (!checked) {
        valid = false;
        showError(`Please select an option for "${name}".`);
      }
    });
    if (!valid) {
      e.preventDefault();
      return false;
    }
    e.preventDefault(); // Prevent default form submission

    // Collect form data
    const data = {
      mood: moodForm.querySelector('input[name="mood"]:checked').value,
      vibe: moodForm.querySelector('input[name="vibe"]:checked').value,
      group: moodForm.querySelector('input[name="group"]:checked').value,
      session: moodForm.querySelector('input[name="session"]:checked').value,
      // Add more fields as needed
    };

    showLoading();
    try {
      const res = await apiRequest('/api/recommend', 'POST', data);
      displayRecommendations(res.recommendations);
    } catch (err) {
      showError('Failed to get recommendations: ' + err.message);
    } finally {
      hideLoading();
    }
  });
  // Real-time validation feedback
  moodForm.querySelectorAll('input[type="radio"]').forEach(input => {
    input.addEventListener('change', () => {
      clearMessages();
    });
  });
}

// Function to display recommendations in the UI
function displayRecommendations(recommendations) {
  const region = document.getElementById('form-messages');
  clearMessages();
  if (!recommendations || recommendations.length === 0) {
    showError('No recommendations found.');
    return;
  }
  // Filter for only movies and TV shows
  const filtered = recommendations.filter(rec => {
    const t = (rec.type || '').toLowerCase();
    return t === 'movie' || t === 'show' || t === 'tv show';
  });
  if (filtered.length === 0) {
    showError('No movies or TV shows found in your recommendations.');
    return;
  }
  // Limit to top 3 results
  const limited = filtered.slice(0, 3);
  const container = document.createElement('div');
  container.className = 'recommendations flex flex-col items-center gap-8 mt-8';
  limited.forEach(rec => {
    const card = document.createElement('div');
    card.className = 'bg-white dark:bg-gray-800 rounded-lg shadow p-6 flex flex-col md:flex-row gap-6 items-center w-full max-w-xl hover:shadow-lg transition';
    let poster = '';
    if (rec.poster_url) {
      poster = `<img src="${rec.poster_url}" alt="Poster for ${rec.title}" class="w-24 h-36 object-cover rounded mb-4 md:mb-0">`;
    }
    // Type badge
    let typeBadge = '';
    if (rec.type) {
      const t = rec.type.toLowerCase();
      let badgeColor = 'bg-indigo-100 text-indigo-700';
      if (t === 'movie') badgeColor = 'bg-indigo-100 text-indigo-700';
      else if (t === 'show' || t === 'tv show') badgeColor = 'bg-yellow-100 text-yellow-800';
      typeBadge = `<span class="inline-block px-2 py-0.5 rounded-full text-xs font-semibold ml-2 ${badgeColor}">${t === 'show' ? 'TV Show' : rec.type.charAt(0).toUpperCase() + rec.type.slice(1)}</span>`;
    }
    card.innerHTML = `
      <div class="flex-shrink-0">${poster}</div>
      <div class="flex-1 w-full">
        <div class="flex items-center mb-1 flex-wrap">
          <span class="font-bold text-xl text-indigo-700 dark:text-indigo-300">${rec.title || ''}</span>
          ${rec.year ? `<span class="text-gray-500 ml-2">(${rec.year})</span>` : ''}
          ${typeBadge}
        </div>
        <div class="text-gray-700 dark:text-gray-200 text-sm mt-1 mb-4">${rec.summary || ''}</div>
        <div class="flex gap-4 mt-2">
          <button class="thumb-btn thumb-up bg-green-100 hover:bg-green-200 text-green-700 rounded-full p-2 transition" aria-label="Thumbs up for ${rec.title}">
            <span class="text-xl">👍</span>
          </button>
          <button class="thumb-btn thumb-down bg-red-100 hover:bg-red-200 text-red-700 rounded-full p-2 transition" aria-label="Thumbs down for ${rec.title}">
            <span class="text-xl">👎</span>
          </button>
        </div>
      </div>
    `;
    // Add event listeners for thumbs
    card.querySelector('.thumb-up').addEventListener('click', () => showToast(`You liked "${rec.title}"!`));
    card.querySelector('.thumb-down').addEventListener('click', () => showToast(`You disliked "${rec.title}".`));
    container.appendChild(card);
  });
  region.appendChild(container);
}

// Helper: Show a toast message
function showToast(msg) {
  let toast = document.getElementById('toast-message');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'toast-message';
    toast.className = 'fixed bottom-6 left-1/2 transform -translate-x-1/2 bg-gray-900 text-white px-6 py-3 rounded-lg shadow-lg z-50 opacity-0 pointer-events-none transition-opacity';
    document.body.appendChild(toast);
  }
  toast.textContent = msg;
  toast.style.opacity = '1';
  toast.style.pointerEvents = 'auto';
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.pointerEvents = 'none';
  }, 1800);
}

// Visual feedback for radio selection and progress
function updateProgressBar() {
  const form = document.getElementById('mood-questionnaire');
  if (!form) return;
  const total = 3;
  let filled = 0;
  ['mood', 'group', 'session'].forEach(name => {
    if (form.querySelector(`input[name="${name}"]:checked`)) filled++;
  });
  const percent = (filled / total) * 100;
  const bar = document.getElementById('progress-bar-inner');
  if (bar) {
    bar.style.width = percent + '%';
    bar.className = 'progress-bar-inner rounded-full shadow transition-all duration-300';
  }
  // Update ARIA attributes for accessibility
  const progressBar = document.querySelector('.progress-bar[role="progressbar"]');
  if (progressBar) {
    progressBar.setAttribute('aria-valuenow', Math.round(percent));
    progressBar.setAttribute('aria-valuetext', `${filled} of ${total} questions answered`);
  }
}

function highlightSelectedRadios() {
  document.querySelectorAll('.mood-options label, .group-options label, .session-options label').forEach(label => {
    const input = label.querySelector('input[type="radio"]');
    const span = label.querySelector('span');
    if (input && span) {
      if (input.checked) {
        span.classList.add('selected');
      } else {
        span.classList.remove('selected');
      }
    }
  });
}

// Attach listeners for visual feedback
const moodForm2 = document.getElementById('mood-questionnaire');
if (moodForm2) {
  moodForm2.querySelectorAll('input[type="radio"]').forEach(input => {
    input.addEventListener('change', () => {
      highlightSelectedRadios();
      updateProgressBar();
    });
  });
  // Initial state
  highlightSelectedRadios();
  updateProgressBar();
}

// Accessible tooltip logic
function hideAllTooltips() {
  document.querySelectorAll('.tooltip .tooltip-text').forEach(tip => {
    tip.style.visibility = 'hidden';
    tip.style.opacity = '0';
  });
}

function showTooltip(tooltip) {
  hideAllTooltips();
  const tip = tooltip.querySelector('.tooltip-text');
  if (tip) {
    tip.style.visibility = 'visible';
    tip.style.opacity = '1';
  }
}

// Animate button presses with a scale effect
function addButtonPressAnimation() {
  document.querySelectorAll('button').forEach(btn => {
    btn.addEventListener('mousedown', () => {
      btn.classList.add('scale-95');
    });
    btn.addEventListener('mouseup', () => {
      btn.classList.remove('scale-95');
    });
    btn.addEventListener('mouseleave', () => {
      btn.classList.remove('scale-95');
    });
    btn.addEventListener('touchend', () => {
      btn.classList.remove('scale-95');
    });
  });
}

// Plex onboarding logic
async function connectToPlex() {
  clearMessages();
  const token = prompt('Enter your Plex token:');
  if (!token) {
    showError('Plex token is required.');
    return;
  }
  const serverName = prompt('Enter Plex server name (optional):');
  showLoading();
  try {
    const res = await apiRequest('/api/plex/connect', 'POST', { token, server_name: serverName });
    showSuccess('Connected to Plex server: ' + res.server);
    updatePlexStatus();
  } catch (err) {
    showError('Failed to connect to Plex: ' + err.message);
  } finally {
    hideLoading();
  }
}

async function updatePlexStatus() {
  try {
    const res = await apiRequest('/api/plex/status');
    const statusEl = document.getElementById('plex-status');
    if (res.connected) {
      statusEl.textContent = 'Connected (' + res.server + ')';
      statusEl.className = 'text-green-600 dark:text-green-400';
    } else {
      statusEl.textContent = 'Not connected';
      statusEl.className = 'text-red-600 dark:text-red-400';
    }
  } catch {
    // fallback
    const statusEl = document.getElementById('plex-status');
    statusEl.textContent = 'Not connected';
    statusEl.className = 'text-red-600 dark:text-red-400';
  }
} 