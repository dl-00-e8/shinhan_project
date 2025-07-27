from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_cors import CORS
import librosa
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
import pickle
import os
import re
from datetime import datetime, timedelta
from werkzeug.utils import secure_filename
import logging
from functools import wraps

# Flask 앱 초기화
app = Flask(__name__)

# 설정
app.config['SECRET_KEY'] = 'your-secret-key-here'
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://username:password@localhost/shinhan_watchos'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = 'jwt-secret-string'
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)
app.config['UPLOAD_FOLDER'] = 'data/uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# 확장 프로그램 초기화
db = SQLAlchemy(app)
migrate = Migrate(app, db)
jwt = JWTManager(app)
CORS(app)

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 업로드 폴더 생성
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# ========================= 데이터베이스 모델 =========================

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    phone_number = db.Column(db.String(20), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)
    
    # 관계
    accounts = db.relationship('Account', backref='user', lazy=True)
    voice_profiles = db.relationship('VoiceProfile', backref='user', lazy=True)

class Account(db.Model):
    __tablename__ = 'accounts'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    account_number = db.Column(db.String(20), unique=True, nullable=False)
    account_type = db.Column(db.String(20), nullable=False)  # 'checking', 'savings'
    balance = db.Column(db.Numeric(15, 2), nullable=False, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)
    
    @property
    def masked_number(self):
        """계좌번호 마스킹 처리"""
        if len(self.account_number) >= 8:
            return f"{self.account_number[:4]}****{self.account_number[-4:]}"
        return self.account_number

class Transaction(db.Model):
    __tablename__ = 'transactions'
    
    id = db.Column(db.Integer, primary_key=True)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    recipient_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    sender_account_id = db.Column(db.Integer, db.ForeignKey('accounts.id'), nullable=False)
    recipient_account_id = db.Column(db.Integer, db.ForeignKey('accounts.id'), nullable=False)
    amount = db.Column(db.Numeric(15, 2), nullable=False)
    fee = db.Column(db.Numeric(10, 2), nullable=False, default=0)
    status = db.Column(db.String(20), nullable=False, default='pending')  # 'pending', 'completed', 'failed'
    transaction_type = db.Column(db.String(20), nullable=False, default='voice_transfer')
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    completed_at = db.Column(db.DateTime)

class VoiceProfile(db.Model):
    __tablename__ = 'voice_profiles'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    voice_features = db.Column(db.LargeBinary, nullable=False)  # MFCC 특성을 pickle로 저장
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)

# ========================= AI 서비스 클래스 =========================

class VoiceAuthenticator:
    def __init__(self):
        self.threshold = 0.85  # 음성 인증 임계치
        self.n_mfcc = 13
        
    def extract_voice_features(self, audio_file_path):
        """음성 파일에서 MFCC 특성 추출"""
        try:
            y, sr = librosa.load(audio_file_path, sr=22050, duration=5.0)
            
            # MFCC 특성 추출
            mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=self.n_mfcc)
            
            # 통계적 특성 계산 (평균, 표준편차)
            mfcc_mean = np.mean(mfcc.T, axis=0)
            mfcc_std = np.std(mfcc.T, axis=0)
            
            # 특성 벡터 결합
            features = np.concatenate([mfcc_mean, mfcc_std])
            
            return features
            
        except Exception as e:
            logger.error(f"음성 특성 추출 오류: {str(e)}")
            return None
    
    def authenticate_voice(self, user_id, current_features):
        """등록된 사용자 음성과 비교하여 인증"""
        try:
            voice_profile = VoiceProfile.query.filter_by(
                user_id=user_id, 
                is_active=True
            ).first()
            
            if not voice_profile:
                return False, 0.0
            
            # 저장된 음성 특성 복원
            registered_features = pickle.loads(voice_profile.voice_features)
            
            # 코사인 유사도 계산
            similarity = cosine_similarity(
                [current_features], 
                [registered_features]
            )[0][0]
            
            is_authenticated = similarity >= self.threshold
            
            logger.info(f"음성 인증 결과 - 사용자 ID: {user_id}, 유사도: {similarity:.3f}, 인증: {is_authenticated}")
            
            return is_authenticated, float(similarity)
            
        except Exception as e:
            logger.error(f"음성 인증 오류: {str(e)}")
            return False, 0.0

class NLPService:
    def __init__(self):
        self.currency_words = {
            '만': 10000,
            '천': 1000,
            '십': 10,
            '백': 100,
        }
    
    def extract_transfer_info(self, text):
        """STT 텍스트에서 이체 정보 추출"""
        try:
            # 수취인 추출 (예: "김철수에게", "홍길동한테")
            recipient_patterns = [
                r'([가-힣]{2,4})(에게|한테|께)',
                r'([가-힣]{2,4})\s*(님)?\s*(에게|한테|께)',
            ]
            
            recipient = None
            for pattern in recipient_patterns:
                match = re.search(pattern, text)
                if match:
                    recipient = match.group(1)
                    break
            
            # 금액 추출
            amount = self._extract_amount(text)
            
            return {
                'recipient': recipient,
                'amount': amount,
                'original_text': text,
                'extracted_successfully': recipient is not None and amount is not None
            }
            
        except Exception as e:
            logger.error(f"텍스트 파싱 오류: {str(e)}")
            return {
                'recipient': None,
                'amount': None,
                'original_text': text,
                'extracted_successfully': False,
                'error': str(e)
            }
    
    def _extract_amount(self, text):
        """텍스트에서 금액 추출"""
        # 숫자 + 단위 패턴 (예: "10만원", "5천원")
        amount_patterns = [
            r'(\d+)\s*만\s*원',
            r'(\d+)\s*천\s*원',
            r'(\d+)\s*원',
            r'(\d+)\s*만',
            r'(\d+)\s*천',
        ]
        
        for pattern in amount_patterns:
            match = re.search(pattern, text)
            if match:
                number = int(match.group(1))
                
                if '만' in pattern:
                    return number * 10000
                elif '천' in pattern:
                    return number * 1000
                else:
                    return number
        
        return None

# 서비스 인스턴스 생성
voice_auth = VoiceAuthenticator()
nlp_service = NLPService()

# ========================= 유틸리티 함수 =========================

def allowed_file(filename):
    """허용된 파일 확장자 확인"""
    ALLOWED_EXTENSIONS = {'wav', 'mp3', 'm4a', 'aac'}
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def format_currency(amount):
    """금액 포맷팅"""
    return f"{amount:,}원"

def calculate_transfer_fee(amount):
    """이체 수수료 계산"""
    if amount <= 10000:
        return 500
    elif amount <= 100000:
        return 1000
    else:
        return 1500

def find_account_by_user_info(recipient_name):
    """수취인 이름으로 계좌 찾기 (실제로는 더 복잡한 검색 로직 필요)"""
    user = User.query.filter_by(username=recipient_name).first()
    if user:
        account = Account.query.filter_by(user_id=user.id, is_active=True).first()
        return account
    return None

# ========================= API 엔드포인트 =========================

@app.route('/api/health', methods=['GET'])
def health_check():
    """서버 상태 확인"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    })

@app.route('/api/auth/login', methods=['POST'])
def login():
    """사용자 로그인"""
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        # 실제로는 비밀번호 해싱 검증 필요
        user = User.query.filter_by(username=username, is_active=True).first()
        
        if user:  # 간단한 인증 (실제로는 bcrypt 등 사용)
            access_token = create_access_token(identity=user.id)
            return jsonify({
                'access_token': access_token,
                'user_id': user.id,
                'username': user.username
            })
        else:
            return jsonify({'error': '인증에 실패했습니다.'}), 401
            
    except Exception as e:
        logger.error(f"로그인 오류: {str(e)}")
        return jsonify({'error': '서버 오류가 발생했습니다.'}), 500

@app.route('/api/accounts/balance', methods=['GET'])
@jwt_required()
def get_account_balance():
    """계좌 잔액 조회"""
    try:
        user_id = get_jwt_identity()
        account = Account.query.filter_by(user_id=user_id, is_active=True).first()
        
        if not account:
            return jsonify({'error': '계좌를 찾을 수 없습니다.'}), 404
        
        # 최근 거래 내역 조회
        recent_transactions = Transaction.query.filter(
            (Transaction.sender_id == user_id) | (Transaction.recipient_id == user_id)
        ).order_by(Transaction.created_at.desc()).limit(5).all()
        
        transactions_data = []
        for tx in recent_transactions:
            transactions_data.append({
                'id': tx.id,
                'amount': float(tx.amount),
                'type': 'out' if tx.sender_id == user_id else 'in',
                'description': tx.description or '이체',
                'created_at': tx.created_at.isoformat(),
                'status': tx.status
            })
        
        return jsonify({
            'balance': float(account.balance),
            'account_number': account.masked_number,
            'account_type': account.account_type,
            'recent_transactions': transactions_data
        })
        
    except Exception as e:
        logger.error(f"잔액 조회 오류: {str(e)}")
        return jsonify({'error': '잔액 조회 중 오류가 발생했습니다.'}), 500

@app.route('/api/transfer/voice-auth', methods=['POST'])
@jwt_required()
def voice_authentication():
    """음성 인증 및 이체 정보 추출"""
    try:
        user_id = get_jwt_identity()
        
        # 음성 파일 업로드 확인
        if 'audio' not in request.files:
            return jsonify({'error': '음성 파일이 필요합니다.'}), 400
        
        audio_file = request.files['audio']
        transfer_text = request.form.get('text', '')
        
        if audio_file.filename == '':
            return jsonify({'error': '파일이 선택되지 않았습니다.'}), 400
        
        if not allowed_file(audio_file.filename):
            return jsonify({'error': '지원되지 않는 파일 형식입니다.'}), 400
        
        # 파일 저장
        filename = secure_filename(f"{user_id}_{datetime.utcnow().timestamp()}_{audio_file.filename}")
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        audio_file.save(file_path)
        
        try:
            # 음성 특성 추출
            voice_features = voice_auth.extract_voice_features(file_path)
            
            if voice_features is None:
                return jsonify({'error': '음성 처리 중 오류가 발생했습니다.'}), 500
            
            # 성문 인식 수행
            is_authenticated, similarity = voice_auth.authenticate_voice(user_id, voice_features)
            
            response_data = {
                'authenticated': is_authenticated,
                'similarity': similarity,
            }
            
            if is_authenticated:
                # 이체 정보 추출
                transfer_info = nlp_service.extract_transfer_info(transfer_text)
                response_data['transfer_info'] = transfer_info
                
                if transfer_info['extracted_successfully']:
                    # 수취인 계좌 찾기
                    recipient_account = find_account_by_user_info(transfer_info['recipient'])
                    if recipient_account:
                        response_data['recipient_account'] = {
                            'account_number': recipient_account.masked_number,
                            'account_id': recipient_account.id
                        }
                    else:
                        response_data['warning'] = '수취인 계좌를 찾을 수 없습니다.'
            else:
                response_data['error'] = '음성 인증에 실패했습니다.'
            
            return jsonify(response_data)
            
        finally:
            # 임시 파일 삭제
            if os.path.exists(file_path):
                os.remove(file_path)
                
    except Exception as e:
        logger.error(f"음성 인증 오류: {str(e)}")
        return jsonify({'error': '음성 인증 처리 중 오류가 발생했습니다.'}), 500

@app.route('/api/transfer/confirm', methods=['POST'])
@jwt_required()
def confirm_transfer_info():
    """이체 정보 확인"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        recipient_name = data.get('recipient')
        amount = data.get('amount')
        recipient_account_id = data.get('recipient_account_id')
        
        if not all([recipient_name, amount, recipient_account_id]):
            return jsonify({'error': '필수 정보가 누락되었습니다.'}), 400
        
        # 수취인 계좌 확인
        recipient_account = Account.query.get(recipient_account_id)
        if not recipient_account:
            return jsonify({'error': '수취인 계좌를 찾을 수 없습니다.'}), 404
        
        # 수수료 계산
        fee = calculate_transfer_fee(amount)
        total_amount = amount + fee
        
        # 송금자 계좌 잔액 확인
        sender_account = Account.query.filter_
