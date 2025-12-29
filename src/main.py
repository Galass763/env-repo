from flask import Flask, jsonify
import os
import logging

app = Flask(__name__)

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.route('/')
def home():
    """Page d'accueil de l'API"""
    logger.info("Home endpoint called")
    return jsonify({
        'status': 'healthy',
        'service': 'myapp',
        'environment': os.getenv('ENVIRONMENT', 'unknown'),
        'version': os.getenv('VERSION', '1.0.0')
    })

@app.route('/health')
def health():
    """Health check endpoint pour Kubernetes liveness probe"""
    return jsonify({'status': 'ok'}), 200

@app.route('/ready')
def ready():
    """Readiness check endpoint pour Kubernetes readiness probe"""
    return jsonify({'status': 'ready'}), 200

@app.route('/api/info')
def info():
    """Informations détaillées sur l'application"""
    return jsonify({
        'application': 'myapp',
        'version': os.getenv('VERSION', '1.0.0'),
        'environment': os.getenv('ENVIRONMENT', 'development'),
        'python_version': '3.9',
        'framework': 'Flask 2.3.0'
    })

@app.route('/api/echo/<message>')
def echo(message):
    """Echo endpoint pour tester"""
    return jsonify({
        'message': message,
        'echo': message.upper()
    })

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    logger.info(f"Starting application on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
