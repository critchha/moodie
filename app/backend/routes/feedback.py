from flask import Blueprint, jsonify

feedback_bp = Blueprint('feedback', __name__)

@feedback_bp.route('/api/feedback', methods=['POST'])
def feedback():
    return jsonify({'error': 'Not implemented'}), 501
