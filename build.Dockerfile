FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy your Python code
COPY . .

# Default command to execute a script (override with docker run)
CMD ["python", "your_script.py"]