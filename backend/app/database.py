import os
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base

# Obter URL do banco de dados das variáveis de ambiente
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://ceriv:ceriv_password@localhost/ceriv_db")

# Criar engine SQLAlchemy assíncrono
engine = create_async_engine(
    DATABASE_URL,
    echo=False,  # Configurar como True para depuração SQL
    future=True,
    pool_size=5,
    max_overflow=10,
)

# Criar fábrica de sessão
SessionLocal = async_sessionmaker(
    engine, 
    class_=AsyncSession, 
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

# Classe base para modelos SQLAlchemy
Base = declarative_base()

# Dependência para obter sessão do banco de dados
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Cria e gerencia uma sessão assíncrona do banco de dados para uso em endpoints.
    Garante que a sessão seja fechada ao final da requisição.
    """
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise