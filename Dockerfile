# Use an official Python image
FROM python:3.9-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt /app/
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# Copy the rest of the code
COPY . /app/

# Expose port
EXPOSE 8000

# Set environment for Flask
ENV FLASK_ENV=production

# Start the backend (serves frontend too)
CMD ["python3", "-m", "app.backend.app", "--port=8000"] 