from flask import Flask, after_this_request

app = Flask(__name__)

@app.after_request
def strip_fingerprint(response):
    # Remove Flask/Werkzeug fingerprints
    response.headers.pop('X-Powered-By', None)
    
    # Genericize Server header (covers WSGI + Python leaks)
    if 'Server' in response.headers:
        response.headers['Server'] = 'webserver'
    
    return response
