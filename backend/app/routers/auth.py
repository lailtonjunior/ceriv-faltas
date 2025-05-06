import logging
from datetime import timedelta
from typing import Dict, Any

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.database import get_db
from app.models import User, Patient
from app.schemas import Token, UserLogin, UserCreate, UserOut, SupabaseAuth
from app.services.security import (
    authenticate_user, create_access_token, 
    get_password_hash, ACCESS_TOKEN_EXPIRE_MINUTES,
    get_current_user, verify_supabase_token
)

# Configuração de logging
logger = logging.getLogger(__name__)

# Criar router
router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Endpoint para obter token JWT através de login com email e senha.
    
    Args:
        form_data: Formulário com credenciais
        db: Sessão do banco de dados
        
    Returns:
        Token JWT
        
    Raises:
        HTTPException: Se as credenciais forem inválidas
    """
    user = await authenticate_user(db, form_data.username, form_data.password)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou senha incorretos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email, "id": user.id, "role": user.role},
        expires_delta=access_token_expires,
    )
    
    # Calcular expiration timestamp para o frontend
    import time
    from datetime import datetime, timedelta
    
    exp_timestamp = int((datetime.utcnow() + access_token_expires).timestamp())
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "exp": exp_timestamp
    }


@router.post("/login", response_model=Token)
async def login(
    login_data: UserLogin,
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Endpoint para login via API.
    
    Args:
        login_data: Dados de login
        db: Sessão do banco de dados
        
    Returns:
        Token JWT
    """
    return await login_for_access_token(
        OAuth2PasswordRequestForm(username=login_data.email, password=login_data.password),
        db
    )


@router.post("/register", response_model=UserOut)
async def register_user(
    user_data: UserCreate, 
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Endpoint para registrar um novo usuário (profissional).
    
    Args:
        user_data: Dados do usuário
        db: Sessão do banco de dados
        
    Returns:
        Usuário criado
        
    Raises:
        HTTPException: Se o email já estiver em uso
    """
    # Verificar se o email já existe
    query = select(User).where(User.email == user_data.email)
    result = await db.execute(query)
    existing_user = result.scalars().first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email já está em uso"
        )
    
    # Criar novo usuário
    hashed_password = get_password_hash(user_data.password)
    
    db_user = User(
        email=user_data.email,
        name=user_data.name,
        role=user_data.role,
        is_active=user_data.is_active,
        avatar_url=user_data.avatar_url,
        fcm_token=user_data.fcm_token,
        hashed_password=hashed_password
    )
    
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    
    return db_user


@router.post("/supabase", response_model=Token)
async def login_with_supabase(
    auth_data: SupabaseAuth,
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Endpoint para autenticação via Supabase Auth.
    
    Args:
        auth_data: Token do Supabase
        db: Sessão do banco de dados
        
    Returns:
        Token JWT interno
    """
    try:
        # Verificar token do Supabase
        payload = await verify_supabase_token(auth_data.token)
        
        # Extrair email do payload
        email = payload.get("email")
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Token do Supabase não contém email"
            )
        
        # Verificar se o usuário existe no banco
        query = select(User).where(User.email == email)
        result = await db.execute(query)
        user = result.scalars().first()
        
        # Se não existir, verificar se é um paciente
        if not user:
            query = select(Patient).where(Patient.email == email)
            result = await db.execute(query)
            patient = result.scalars().first()
            
            if not patient:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Usuário não encontrado"
                )
            
            # Criar token para paciente
            access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
            access_token = create_access_token(
                data={"sub": patient.email, "id": patient.id, "role": "patient"},
                expires_delta=access_token_expires,
            )
            
            # Atualizar supabase_id se necessário
            if not patient.supabase_id:
                patient.supabase_id = payload.get("sub")
                await db.commit()
                
            # Calcular expiration timestamp para o frontend
            exp_timestamp = int((datetime.utcnow() + access_token_expires).timestamp())
            
            return {
                "access_token": access_token,
                "token_type": "bearer",
                "exp": exp_timestamp
            }
        
        # Criar token para usuário existente
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user.email, "id": user.id, "role": user.role},
            expires_delta=access_token_expires,
        )
        
        # Calcular expiration timestamp para o frontend
        exp_timestamp = int((datetime.utcnow() + access_token_expires).timestamp())
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "exp": exp_timestamp
        }
        
    except Exception as e:
        logger.error(f"Erro no login Supabase: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Falha na autenticação via Supabase",
            headers={"WWW-Authenticate": "Bearer"},
        )


@router.get("/me", response_model=UserOut)
async def read_users_me(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Endpoint para obter informações do usuário logado.
    
    Args:
        current_user: Usuário atual
        
    Returns:
        Dados do usuário
    """
    return current_user