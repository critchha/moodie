from flask import Blueprint, jsonify

train_bp = Blueprint('train', __name__)

@train_bp.route('/api/train', methods=['POST'])
def train_model():
    return jsonify({'error': 'Not implemented'}), 501
