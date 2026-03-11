FROM python:3.14-slim

# Install make and build essentials
RUN apt-get update && apt-get install -y \
    make \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Docker Python SDK and other essentials
RUN pip install --no-cache-dir docker

# Copy project files
COPY . .

# Default command runs make
CMD ["make"]
