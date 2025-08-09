from flask import Flask, request, jsonify
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
from collections import defaultdict
import uuid
import threading


# Flask 앱 초기화
app = Flask(__name__)

# 설정
app.config['SECRET_KEY'] = 'your-secret-key-here'
app.config['JWT_SECRET_KEY'] = 'jwt-secret-string'
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)
app.config['UPLOAD_FOLDER'] = 'data/uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# 확장 프로그램 초기화
jwt = JWTManager(app)
CORS(app)

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 업로드 폴더 생성
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# 데이터 동기화용 락
data_lock = threading.RLock()

# ========================= 인메모리 데이터 구조 =========================

class DataStore:
    def __init__(self):
        self.users = {}  # user_id -> user_data
        self.accounts = {}  # account_id -> account_data
        self.transactions = {}  # transaction_id -> transaction_data
        self.voice_profiles = {}  # user_id -> voice_profile_data
        
        # ID 카운터
        self.next_user_id = 1
        self.next_account_id = 1
        self.next_transaction_id = 1
        
        # 사용자별 계좌 인덱스
        self.user_accounts = defaultdict(list)  # user_id -> [account_id, ...]
        
        self._init_test_data()
    
    def _init_test_data(self):
        """테스트용 초기 데이터 생성"""
        # 테스트 사용자 1
        user1_id = self.create_user(
            username="testuser1",
            email="test1@example.com",
            password_hash="hashed_password_1",
            phone_number="010-1234-5678"
        )
        
        # 테스트 사용자 2
        user2_id = self.create_user(
            username="김철수",
            email="kim@example.com",
            password_hash="hashed_password_2",
            phone_number="010-9876-5432"
        )
        
        # 테스트 사용자 3
        user3_id = self.create_user(
            username="홍길동",
            email="hong@example.com",
            password_hash="hashed_password_3",
            phone_number="010-5555-1234"
        )
        
        # 계좌 생성
        self.create_account(user1_id, "1234567890123456", "checking", 1000000)
        self.create_account(user2_id, "2345678901234567", "savings", 500000)
        self.create_account(user3_id, "3456789012345678", "checking", 750000)
        
        logger.info("테스트 데이터 초기화 완료")
        logger.info(f"사용자 수: {len(self.users)}")
        logger.info(f"계좌 수: {len(self.accounts)}")
    
    def create_user(self, username, email, password_hash, phone_number):
        """사용자 생성"""
        with data_lock:
            user_id = self.next_user_id
            self.next_user_id += 1
            
            user_data = {
                'id': user_id,
                'username': username,
                'email': email,
                'password_hash': password_hash,
                'phone_number': phone_number,
                'created_at': datetime.utcnow(),
                'is_active': True
            }
            
            self.users[user_id] = user_data
            return user_id
    
    def create_account(self, user_id, account_number, account_type, initial_balance=0):
        """계좌 생성"""
        with data_lock:
            account_id = self.next_account_id
            self.next_account_id += 1
            
            account_data = {
                'id': account_id,
                'user_id': user_id,
                'account_number': account_number,
                'account_type': account_type,
                'balance': initial_balance,
                'created_at': datetime.utcnow(),
                'is_active': True
            }
            
            self.accounts[account_id] = account_data
            self.user_accounts[user_id].append(account_id)
            return account_id
    
    def create_transaction(self, sender_id, recipient_id, sender_account_id, 
                          recipient_account_id, amount, fee=0, description=None):
        """거래 생성"""
        with data_lock:
            transaction_id = self.next_transaction_id
            self.next_transaction_id += 1
            
            transaction_data = {
                'id': transaction_id,
                'sender_id': sender_id,
                'recipient_id': recipient_id,
                'sender_account_id': sender_account_id,
                'recipient_account_id': recipient_account_id,
                'amount': amount,
                'fee': fee,
                'status': 'pending',
                'transaction_type': 'voice_transfer',
                'description': description,
                'created_at': datetime.utcnow(),
                'completed_at': None
            }
            
            self.transactions[transaction_id] = transaction_data
            return transaction_id
    
    def get_user_by_username(self, username):
        """사용자명으로 사용자 검색"""
        for user_data in self.users.values():
            if user_data['username'] == username and user_data['is_active']:
                return user_data
        return None
    
    def get_user_accounts(self, user_id):
        """사용자 계좌 목록 조회"""
        account_ids = self.user_accounts.get(user_id, [])
        accounts = []
        for account_id in account_ids:
            account = self.accounts.get(account_id)
            if account and account['is_active']:
                accounts.append(account)
        return accounts
    
    def get_user_transactions(self, user_id, limit=None):
        """사용자 거래 내역 조회"""
        transactions = []
        for tx in self.transactions.values():
            if tx['sender_id'] == user_id or tx['recipient_id'] == user_id:
                transactions.append(tx)
        
        # 최신 순으로 정렬
        transactions.sort(key=lambda x: x['created_at'], reverse=True)
        
        if limit:
            transactions = transactions[:limit]
        
        return transactions
    
    def update_account_balance(self, account_id, new_balance):
        """계좌 잔액 업데이트"""
        with data_lock:
            if account_id in self.accounts:
                self.accounts[account_id]['balance'] = new_balance
                return True
            return False
    
    def update_transaction_status(self, transaction_id, status):
        """거래 상태 업데이트"""
        with data_lock:
            if transaction_id in self.transactions:
                self.transactions[transaction_id]['status'] = status
                if status == 'completed':
                    self.transactions[transaction_id]['completed_at'] = datetime.utcnow()
                return True
            return False
    
    def create_voice_profile(self, user_id, voice_features):
        """음성 프로필 생성/업데이트"""
        with data_lock:
            self.voice_profiles[user_id] = {
                'user_id': user_id,
                'voice_features': voice_features,
                'created_at': datetime.utcnow(),
                'updated_at': datetime.utcnow(),
                'is_active': True
            }
    
    def get_voice_profile(self, user_id):
        """음성 프로필 조회"""
        return self.voice_profiles.get(user_id)

# 데이터 저장소 인스턴스
data_store = DataStore()

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
            voice_profile = data_store.get_voice_profile(user_id)
            
            if not voice_profile or not voice_profile['is_active']:
                return False, 0.0
            
            # 저장된 음성 특성 복원
            registered_features = voice_profile['voice_features']
            
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
    """수취인 이름으로 계좌 찾기"""
    user = data_store.get_user_by_username(recipient_name)
    if user:
        accounts = data_store.get_user_accounts(user['id'])
        if accounts:
            return accounts[0]  # 첫 번째 활성 계좌 반환
    return None

def mask_account_number(account_number):
    """계좌번호 마스킹 처리"""
    if len(account_number) >= 8:
        return f"{account_number[:4]}****{account_number[-4:]}"
    return account_number

# ========================= API 엔드포인트 =========================

@app.route('/api/health', methods=['GET'])
def health_check():
    """서버 상태 확인"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0',
        'users_count': len(data_store.users),
        'accounts_count': len(data_store.accounts),
        'transactions_count': len(data_store.transactions)
    })

@app.route('/api/auth/login', methods=['POST'])
def login():
    """사용자 로그인"""
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        # 사용자 검색
        user = data_store.get_user_by_username(username)
        
        if user:  # 간단한 인증 (실제로는 bcrypt 등 사용)
            access_token = create_access_token(identity=user['id'])
            return jsonify({
                'access_token': access_token,
                'user_id': user['id'],
                'username': user['username']
            })
        else:
            return jsonify({'error': '인증에 실패했습니다.'}), 401
            
    except Exception as e:
        logger.error(f"로그인 오류: {str(e)}")
        return jsonify({'error': '서버 오류가 발생했습니다.'}), 500

@app.route('/api/accounts', methods=['GET'])
@jwt_required()
def get_accounts():
    """사용자 계좌 목록 조회 (Swift Account 형식)"""
    try:
        user_id = get_jwt_identity()
        user = data_store.users.get(user_id)
        
        if not user:
            return jsonify({'error': '사용자를 찾을 수 없습니다.'}), 404
        
        accounts = data_store.get_user_accounts(user_id)
        
        # Swift Account 형식으로 변환
        swift_accounts = []
        for account in accounts:
            swift_account = format_account_for_swift(account, user)
            swift_accounts.append(swift_account)
        
        return jsonify({
            'accounts': swift_accounts,
            'count': len(swift_accounts)
        })
        
    except Exception as e:
        logger.error(f"계좌 목록 조회 오류: {str(e)}")
        return jsonify({'error': '계좌 조회 중 오류가 발생했습니다.'}), 500

@app.route('/api/transfer/voice', methods=['POST'])
@jwt_required()
def voice_transfer():
    """음성 이체 (Swift 호환 통합 엔드포인트)"""
    try:
        user_id = get_jwt_identity()
        
        # 음성 파일 업로드 확인
        if 'audio' not in request.files:
            return jsonify(create_transfer_result_for_swift(
                False, '음성 파일이 필요합니다.'
            )), 400
        
        audio_file = request.files['audio']
        transfer_text = request.form.get('text', '')
        
        if audio_file.filename == '':
            return jsonify(create_transfer_result_for_swift(
                False, '파일이 선택되지 않았습니다.'
            )), 400
        
        if not allowed_file(audio_file.filename):
            return jsonify(create_transfer_result_for_swift(
                False, '지원되지 않는 파일 형식입니다.'
            )), 400
        
        # 파일 저장
        filename = secure_filename(f"{user_id}_{datetime.utcnow().timestamp()}_{audio_file.filename}")
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        audio_file.save(file_path)
        
        try:
            # 1. 음성 특성 추출
            voice_features = voice_auth.extract_voice_features(file_path)
            
            if voice_features is None:
                return jsonify(create_transfer_result_for_swift(
                    False, '음성 처리 중 오류가 발생했습니다.'
                )), 500
            
            # 2. 음성 인증
            is_authenticated, similarity = voice_auth.authenticate_voice(user_id, voice_features)
            
            if not is_authenticated:
                return jsonify(create_transfer_result_for_swift(
                    False, f'음성 인증에 실패했습니다. (유사도: {similarity:.2f})'
                )), 401
            
            # 3. 이체 정보 추출
            transfer_info = nlp_service.extract_transfer_info(transfer_text)
            
            if not transfer_info['extracted_successfully']:
                return jsonify(create_transfer_result_for_swift(
                    False, '이체 정보를 추출할 수 없습니다. 다시 말씀해주세요.'
                )), 400
            
            recipient_name = transfer_info['recipient']
            amount = transfer_info['amount']
            
            # 4. 수취인 계좌 찾기
            recipient_account = find_account_by_user_info(recipient_name)
            if not recipient_account:
                return jsonify(create_transfer_result_for_swift(
                    False, f'{recipient_name}님의 계좌를 찾을 수 없습니다.'
                )), 404
            
            # 5. 송금자 계좌 조회
            sender_accounts = data_store.get_user_accounts(user_id)
            if not sender_accounts:
                return jsonify(create_transfer_result_for_swift(
                    False, '송금자 계좌를 찾을 수 없습니다.'
                )), 404
            
            sender_account = sender_accounts[0]
            
            # 6. 잔액 확인
            fee = calculate_transfer_fee(amount)
            total_amount = amount + fee
            
            if sender_account['balance'] < total_amount:
                return jsonify(create_transfer_result_for_swift(
                    False, f'계좌 잔액이 부족합니다. (필요: {format_currency(total_amount)}, 잔액: {format_currency(sender_account["balance"])})'
                )), 400
            
            # 7. 이체 실행
            transaction_id = data_store.create_transaction(
                sender_id=user_id,
                recipient_id=recipient_account['user_id'],
                sender_account_id=sender_account['id'],
                recipient_account_id=recipient_account['id'],
                amount=amount,
                fee=fee,
                description=f"{recipient_name}에게 음성 이체"
            )
            
            # 8. 계좌 잔액 업데이트
            new_sender_balance = sender_account['balance'] - total_amount
            new_recipient_balance = recipient_account['balance'] + amount
            
            data_store.update_account_balance(sender_account['id'], new_sender_balance)
            data_store.update_account_balance(recipient_account['id'], new_recipient_balance)
            data_store.update_transaction_status(transaction_id, 'completed')
            
            logger.info(f"음성 이체 완료 - 거래 ID: {transaction_id}, {recipient_name}에게 {format_currency(amount)}")
            
            return jsonify(create_transfer_result_for_swift(
                True,
                f'{recipient_name}님에게 {format_currency(amount)} 이체가 완료되었습니다.',
                transaction_id
            ))
            
        finally:
            # 임시 파일 삭제
            if os.path.exists(file_path):
                os.remove(file_path)
                
    except Exception as e:
        logger.error(f"음성 이체 오류: {str(e)}")
        return jsonify(create_transfer_result_for_swift(
            False, '이체 처리 중 오류가 발생했습니다.'
        )), 500

@app.route('/api/transfer', methods=['POST'])
@jwt_required()
def transfer():
    """일반 이체 (Swift TransferRequest 호환)"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        # Swift TransferRequest 파싱
        transfer_data = parse_transfer_request_from_swift(data)
        
        recipient_name = transfer_data['recipient_name']
        amount = transfer_data['amount']
        from_account = transfer_data['from_account']
        memo = transfer_data['memo']
        voice_score = transfer_data['voice_authentication_score']
        
        if not all([recipient_name, amount]):
            return jsonify(create_transfer_result_for_swift(
                False, '필수 정보가 누락되었습니다.'
            )), 400
        
        # 음성 인증 점수 확인
        if voice_score and voice_score < 0.85:
            return jsonify(create_transfer_result_for_swift(
                False, f'음성 인증 점수가 낮습니다. ({voice_score:.2f})'
            )), 401
        
        # 수취인 계좌 찾기
        recipient_account = find_account_by_user_info(recipient_name)
        if not recipient_account:
            return jsonify(create_transfer_result_for_swift(
                False, f'{recipient_name}님의 계좌를 찾을 수 없습니다.'
            )), 404
        
        # 송금자 계좌 찾기
        sender_accounts = data_store.get_user_accounts(user_id)
        sender_account = None
        
        if from_account:
            # 특정 계좌 지정된 경우
            for acc in sender_accounts:
                if acc['account_number'] == from_account:
                    sender_account = acc
                    break
        else:
            # 첫 번째 계좌 사용
            sender_account = sender_accounts[0] if sender_accounts else None
        
        if not sender_account:
            return jsonify(create_transfer_result_for_swift(
                False, '송금자 계좌를 찾을 수 없습니다.'
            )), 404
        
        # 잔액 확인
        fee = calculate_transfer_fee(amount)
        total_amount = amount + fee
        
        if sender_account['balance'] < total_amount:
            return jsonify(create_transfer_result_for_swift(
                False, f'계좌 잔액이 부족합니다.'
            )), 400
        
        # 이체 실행
        transaction_id = data_store.create_transaction(
            sender_id=user_id,
            recipient_id=recipient_account['user_id'],
            sender_account_id=sender_account['id'],
            recipient_account_id=recipient_account['id'],
            amount=amount,
            fee=fee,
            description=memo or f"{recipient_name}에게 이체"
        )
        
        # 계좌 잔액 업데이트
        new_sender_balance = sender_account['balance'] - total_amount
        new_recipient_balance = recipient_account['balance'] + amount
        
        data_store.update_account_balance(sender_account['id'], new_sender_balance)
        data_store.update_account_balance(recipient_account['id'], new_recipient_balance)
        data_store.update_transaction_status(transaction_id, 'completed')
        
        logger.info(f"이체 완료 - 거래 ID: {transaction_id}")
        
        return jsonify(create_transfer_result_for_swift(
            True,
            f'{recipient_name}님에게 {format_currency(amount)} 이체가 완료되었습니다.',
            transaction_id
        ))
        
    except Exception as e:
        logger.error(f"이체 오류: {str(e)}")
        return jsonify(create_transfer_result_for_swift(
            False, '이체 처리 중 오류가 발생했습니다.'
        )), 500

@app.route('/api/transfer/execute', methods=['POST'])
@jwt_required()
def execute_transfer():
    """이체 실행"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        transaction_id = data.get('transaction_id')
        
        if not transaction_id:
            return jsonify({'error': '거래 ID가 필요합니다.'}), 400
        
        # 거래 정보 확인
        transaction = data_store.transactions.get(transaction_id)
        if not transaction:
            return jsonify({'error': '거래를 찾을 수 없습니다.'}), 404
        
        if transaction['sender_id'] != user_id:
            return jsonify({'error': '권한이 없습니다.'}), 403
        
        if transaction['status'] != 'pending':
            return jsonify({'error': '이미 처리된 거래입니다.'}), 400
        
        # 계좌 정보 조회
        sender_account = data_store.accounts[transaction['sender_account_id']]
        recipient_account = data_store.accounts[transaction['recipient_account_id']]
        
        total_amount = transaction['amount'] + transaction['fee']
        
        # 잔액 재확인
        if sender_account['balance'] < total_amount:
            data_store.update_transaction_status(transaction_id, 'failed')
            return jsonify({'error': '계좌 잔액이 부족합니다.'}), 400
        
        # 이체 실행
        new_sender_balance = sender_account['balance'] - total_amount
        new_recipient_balance = recipient_account['balance'] + transaction['amount']
        
        data_store.update_account_balance(sender_account['id'], new_sender_balance)
        data_store.update_account_balance(recipient_account['id'], new_recipient_balance)
        data_store.update_transaction_status(transaction_id, 'completed')
        
        logger.info(f"이체 완료 - 거래 ID: {transaction_id}, 금액: {transaction['amount']}")
        
        return jsonify({
            'success': True,
            'transaction_id': transaction_id,
            'amount': transaction['amount'],
            'fee': transaction['fee'],
            'new_balance': new_sender_balance,
            'status': 'completed'
        })
    
    except Exception as e:
        logger.error(f"이체 실행 오류: {str(e)}")
        return jsonify({'error': '이체 실행 중 오류가 발생했습니다.'}), 500

@app.route('/api/voice/register', methods=['POST'])
@jwt_required()
def register_voice():
    """음성 프로필 등록"""
    try:
        user_id = get_jwt_identity()
        
        if 'audio' not in request.files:
            return jsonify({'error': '음성 파일이 필요합니다.'}), 400
        
        audio_file = request.files['audio']
        
        if not allowed_file(audio_file.filename):
            return jsonify({'error': '지원되지 않는 파일 형식입니다.'}), 400
        
        # 파일 저장
        filename = secure_filename(f"voice_reg_{user_id}_{datetime.utcnow().timestamp()}_{audio_file.filename}")
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        audio_file.save(file_path)
        
        try:
            # 음성 특성 추출
            voice_features = voice_auth.extract_voice_features(file_path)
            
            if voice_features is None:
                return jsonify({'error': '음성 처리 중 오류가 발생했습니다.'}), 500
            
            # 음성 프로필 저장
            data_store.create_voice_profile(user_id, voice_features)
            
            return jsonify({
                'success': True,
                'message': '음성 프로필이 등록되었습니다.'
            })
            
        finally:
            # 임시 파일 삭제
            if os.path.exists(file_path):
                os.remove(file_path)
    
    except Exception as e:
        logger.error(f"음성 등록 오류: {str(e)}")
        return jsonify({'error': '음성 등록 중 오류가 발생했습니다.'}), 500

@app.route('/api/users/list', methods=['GET'])
def list_users():
    """사용자 목록 조회 (테스트용)"""
    users_list = []
    for user in data_store.users.values():
        if user['is_active']:
            users_list.append({
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'phone_number': user['phone_number']
            })
    
    return jsonify({
        'users': users_list,
        'count': len(users_list)
    })

if __name__ == '__main__':
    print("=== 신한은행 음성인식 이체 서비스 ===")
    print("테스트 사용자:")
    for user in data_store.users.values():
        accounts = data_store.get_user_accounts(user['id'])
        account_info = ""
        if accounts:
            account = accounts[0]
            account_info = f" | 계좌: {mask_account_number(account['account_number'])} | 잔액: {format_currency(account['balance'])}"
        print(f"- {user['username']} ({user['email']}){account_info}")
    
    print("\n사용 가능한 API 엔드포인트:")
    print("- POST /api/auth/login - 로그인")
    print("- GET  /api/health - 서버 상태 확인")
    print("- GET  /api/accounts/balance - 계좌 잔액 조회")
    print("- POST /api/voice/register - 음성 프로필 등록")
    print("- POST /api/transfer/voice-auth - 음성 인증 및 이체 정보 추출")
    print("- POST /api/transfer/confirm - 이체 정보 확인")
    print("- POST /api/transfer/execute - 이체 실행")
    print("- GET  /api/users/list - 사용자 목록 (테스트용)")
    
    print(f"\n서버 시작중... http://127.0.0.1:8080")
    app.run(debug=True, host='0.0.0.0', port=8080)