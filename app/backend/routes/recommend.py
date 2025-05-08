from flask import Blueprint, jsonify

recommend_bp = Blueprint('recommend', __name__)

@recommend_bp.route('/api/recommend', methods=['GET'])
def recommend():
    return jsonify({'status': 'not implemented'})
