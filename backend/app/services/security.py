import os
import logging
from datetime import datetime, timedelta
from typing import Optional, Union, Dict, Any

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.database import get_db
from app.models import User
from app.schemas import TokenData, UserOut

# Configuração de logging
logger = logging.getLogger(__name__)

# Configurações de segurança
SECRET_KEY = os.getenv("API_SECRET_KEY", "muito_secreto_mudar_em_producao")
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "jwt_muito_secreto_mudar_em_producao")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

# Contexto para hash de senhas
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 para endpoints protegidos
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/token")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica se a senha em texto plano corresponde ao hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Gera um hash seguro da senha."""
    return pwd_context.hash(password)


def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """
    Cria um token JWT para autenticação.
    
    Args:
        data: Dados a serem codificados no token
        expires_delta: Tempo de validade do token
        
    Returns:
        Token JWT codificado
    """
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=ALGORITHM)
    
    return encoded_jwt


async def get_user_by_email(db: AsyncSession, email: str) -> Optional[User]:
    """
    Busca um usuário pelo email.
    
    Args:
        db: Sessão do banco de dados
        email: Email do usuário
        
    Returns:
        Usuário encontrado ou None
    """
    query = select(User).where(User.email == email)
    result = await db.execute(query)
    return result.scalars().first()


async def authenticate_user(db: AsyncSession, email: str, password: str) -> Optional[User]:
    """
    Autentica um usuário pelo email e senha.
    
    Args:
        db: Sessão do banco de dados
        email: Email do usuário
        password: Senha do usuário
        
    Returns:
        Usuário autenticado ou None
    """
    user = await get_user_by_email(db, email)
    
    if not user:
        return None
    
    if not verify_password(password, user.hashed_password):
        return None
    
    return user


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Obtém o usuário atual a partir do token JWT.
    
    Args:
        token: Token JWT
        db: Sessão do banco de dados
        
    Returns:
        Usuário atual
        
    Raises:
        HTTPException: Se o token for inválido ou o usuário não for encontrado
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciais inválidas",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        
        if email is None:
            raise credentials_exception
        
        token_data = TokenData(sub=email, exp=payload.get("exp"), role=payload.get("role", "user"))
    except JWTError as e:
        logger.error(f"Erro ao decodificar token: {e}")
        raise credentials_exception
    
    user = await get_user_by_email(db, email=token_data.sub)
    
    if user is None:
        raise credentials_exception
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuário inativo"
        )
    
    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Verifica se o usuário atual está ativo.
    
    Args:
        current_user: Usuário atual
        
    Returns:
        Usuário ativo
        
    Raises:
        HTTPException: Se o usuário estiver inativo
    """
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuário inativo"
        )
    
    return current_user


def verify_admin_access(user: User) -> None:
    """
    Verifica se o usuário tem acesso de administrador.
    
    Args:
        user: Usuário a ser verificado
        
    Raises:
        HTTPException: Se o usuário não tiver permissão de administrador
    """
    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso administrativo necessário"
        )


# Função para verificar token do Supabase
async def verify_supabase_token(token: str) -> Dict[str, Any]:
    """
    Verifica um token JWT do Supabase.
    
    Args:
        token: Token JWT do Supabase
        
    Returns:
        Payload do token
        
    Raises:
        HTTPException: Se o token for inválido
    """
    try:
        # Em um ambiente real, você usaria a chave pública do Supabase para verificar
        # Aqui estamos apenas decodificando o token para fins de demonstração
        payload = jwt.decode(
            token, 
            os.getenv("SUPABASE_JWT_SECRET", "supabase_secret"), 
            algorithms=["HS256"]
        )
        return payload
    except JWTError as e:
        logger.error(f"Erro ao verificar token do Supabase: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token do Supabase inválido",
            headers={"WWW-Authenticate": "Bearer"},
        )