// app/frontend/js/app.js

// Utility: Show/hide sections
function showSection(id) {
  document.querySelectorAll('.section').forEach(sec => sec.classList.add('hidden'));
  document.getElementById(id).classList.remove('hidden');
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

// Example: Show error message
function showError(msg) {
  let el = document.getElementById('error-message');
  if (!el) {
    el = document.createElement('div');
    el.id = 'error-message';
    el.style.color = 'red';
    el.style.margin = '1rem 0';
    document.querySelector('main').prepend(el);
  }
  el.textContent = msg;
}

// Example: Clear error message
function clearError() {
  const el = document.getElementById('error-message');
  if (el) el.remove();
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
  clearError();
  hideLoading();
  showSection('mood-form');
  // Add more initialization as needed
}); 