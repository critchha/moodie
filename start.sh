#!/bin/bash

# Exit on error
set -e

# 1. Create venv if missing
if [ ! -d "venv" ]; then
  echo "Creating virtual environment..."
  python3 -m venv venv
fi

# 2. Activate venv
source venv/bin/activate

# 3. Install requirements
if [ -f requirements.txt ]; then
  echo "Installing dependencies..."
  pip install -r requirements.txt
else
  echo "requirements.txt not found! Exiting."
  exit 1
fi

# 4. Start backend (in background)
echo "Starting backend server..."
PYTHONPATH=$(pwd) nohup python3 -m app.backend.app > backend.log 2>&1 &
BACKEND_PID=$!
echo "Backend started with PID $BACKEND_PID (logs: backend.log)"

# 5. Open frontend in browser
echo "Opening http://localhost:5000 in your browser..."
open http://localhost:5000 || xdg-open http://localhost:5000 || echo "Please open http://localhost:5000 manually."

# 6. Print instructions
echo "---"
echo "To stop the backend server, run: kill $BACKEND_PID"
echo "To deactivate the virtual environment, run: deactivate"
echo "---" 