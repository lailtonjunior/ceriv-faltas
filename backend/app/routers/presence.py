import logging
import os
from datetime import datetime
from typing import List, Optional
from geopy.distance import geodesic

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Presence, Patient, User
from app.schemas import PresenceCreate, PresenceOut, QRPresenceCreate
from app.services.security import get_current_user

# Configuração de logging
logger = logging.getLogger(__name__)

# Criar router
router = APIRouter(prefix="/presences", tags=["presences"])

# Configurações de geolocalização
CERIV_LATITUDE = float(os.getenv("CERIV_LATITUDE", "-23.5505"))
CERIV_LONGITUDE = float(os.getenv("CERIV_LONGITUDE", "-46.6333"))
CERIV_GEOFENCE_RADIUS = float(os.getenv("CERIV_GEOFENCE_RADIUS", "100"))  # em metros


@router.post("/", response_model=PresenceOut)
async def create_presence(
    presence: PresenceCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> Presence:
    """
    Cria um novo registro de presença.
    
    Args:
        presence: Dados da presença
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Presença criada
    """
    # Verificar se o paciente existe
    patient_query = select(Patient).where(Patient.id == presence.patient_id)
    patient_result = await db.execute(patient_query)
    patient = patient_result.scalars().first()
    
    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Paciente com ID {presence.patient_id} não encontrado"
        )
    
    # Criar novo registro de presença
    db_presence = Presence(
        patient_id=presence.patient_id,
        date=presence.date or datetime.now(),
        latitude=presence.latitude,
        longitude=presence.longitude,
        method=presence.method,
        confirmed=presence.confirmed,
        confirmed_by=current_user.id if presence.confirmed else None,
        notes=presence.notes
    )
    
    db.add(db_presence)
    await db.commit()
    await db.refresh(db_presence)
    
    return db_presence


@router.post("/qr", response_model=PresenceOut)
async def register_qr_presence(
    presence_data: QRPresenceCreate,
    db: AsyncSession = Depends(get_db)
) -> Presence:
    """
    Registra presença via QR Code com validação de geolocalização.
    
    Args:
        presence_data: Dados da presença via QR
        db: Sessão do banco de dados
        
    Returns:
        Presença registrada
        
    Raises:
        HTTPException: Se a validação do QR Code falhar ou a localização estiver fora do perímetro
    """
    # Verificar QR Code (simplificado para o exemplo)
    # Em produção, seria implementada uma validação mais segura
    expected_qr = "CER-IV-PRESENCE"
    if presence_data.qr_code != expected_qr:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="QR Code inválido"
        )
    
    # Verificar se o paciente existe
    patient_query = select(Patient).where(Patient.id == presence_data.patient_id)
    patient_result = await db.execute(patient_query)
    patient = patient_result.scalars().first()
    
    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Paciente com ID {presence_data.patient_id} não encontrado"
        )
    
    # Verificar geolocalização
    user_location = (presence_data.latitude, presence_data.longitude)
    cer_location = (CERIV_LATITUDE, CERIV_LONGITUDE)
    
    distance = geodesic(user_location, cer_location).meters
    
    if distance > CERIV_GEOFENCE_RADIUS:
        logger.warning(
            f"Tentativa de registro fora do perímetro. Distância: {distance:.2f}m. "
            f"Paciente: {patient.id}. Coordenadas: {user_location}"
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Localização fora do perímetro do CER IV (distância: {distance:.2f}m)"
        )
    
    # Verificar se já existe presença para o paciente hoje
    today = datetime.now().date()
    presence_query = select(Presence).where(
        Presence.patient_id == presence_data.patient_id,
        func.date(Presence.date) == today
    )
    presence_result = await db.execute(presence_query)
    existing_presence = presence_result.scalars().first()
    
    if existing_presence:
        logger.info(f"Presença já registrada hoje para o paciente {patient.id}")
        return existing_presence
    
    # Criar novo registro de presença
    db_presence = Presence(
        patient_id=presence_data.patient_id,
        date=datetime.now(),
        latitude=presence_data.latitude,
        longitude=presence_data.longitude,
        method="qr",
        confirmed=True,
        notes="Presença via QR Code"
    )
    
    db.add(db_presence)
    await db.commit()
    await db.refresh(db_presence)
    
    # Aqui seria chamado o serviço de gamificação para verificar badges
    # await gamification_service.check_presence_badges(db, patient.id)
    
    return db_presence


@router.get("/", response_model=List[PresenceOut])
async def read_presences(
    skip: int = 0,
    limit: int = 100,
    patient_id: Optional[int] = None,
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> List[Presence]:
    """
    Retorna a lista de presenças, com opção de filtro por paciente e data.
    
    Args:
        skip: Número de registros para pular
        limit: Número máximo de registros
        patient_id: ID do paciente para filtrar
        date_from: Data inicial para filtrar
        date_to: Data final para filtrar
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Lista de presenças
    """
    query = select(Presence)
    
    # Aplicar filtros
    if patient_id:
        query = query.where(Presence.patient_id == patient_id)
    
    if date_from:
        query = query.where(Presence.date >= date_from)
    
    if date_to:
        query = query.where(Presence.date <= date_to)
    
    # Ordenar e limitar
    query = query.order_by(Presence.date.desc()).offset(skip).limit(limit)
    
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{presence_id}", response_model=PresenceOut)
async def read_presence(
    presence_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> Presence:
    """
    Retorna um registro de presença específico.
    
    Args:
        presence_id: ID da presença
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Presença encontrada
        
    Raises:
        HTTPException: Se a presença não for encontrada
    """
    query = select(Presence).where(Presence.id == presence_id)
    result = await db.execute(query)
    presence = result.scalars().first()
    
    if not presence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Presença com ID {presence_id} não encontrada"
        )
    
    return presence


@router.get("/patient/{patient_id}/stats", response_model=dict)
async def get_patient_presence_stats(
    patient_id: int,
    period: str = Query("month", regex="^(week|month|quarter|year)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> dict:
    """
    Retorna estatísticas de presença para um paciente.
    
    Args:
        patient_id: ID do paciente
        period: Período para as estatísticas (week, month, quarter, year)
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Estatísticas de presença
    """
    # Verificar se o paciente existe
    patient_query = select(Patient).where(Patient.id == patient_id)
    patient_result = await db.execute(patient_query)
    patient = patient_result.scalars().first()
    
    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Paciente com ID {patient_id} não encontrado"
        )
    
    # Definir intervalo de data com base no período
    today = datetime.now().date()
    
    if period == "week":
        from_date = today.replace(day=today.day - today.weekday())
    elif period == "month":
        from_date = today.replace(day=1)
    elif period == "quarter":
        month = ((today.month - 1) // 3) * 3 + 1
        from_date = today.replace(month=month, day=1)
    elif period == "year":
        from_date = today.replace(month=1, day=1)
    else:
        from_date = today.replace(day=1)  # default: month
    
    # Contar presenças no período
    presence_query = select(func.count(Presence.id)).where(
        Presence.patient_id == patient_id,
        func.date(Presence.date) >= from_date,
        func.date(Presence.date) <= today
    )
    presence_result = await db.execute(presence_query)
    presence_count = presence_result.scalar()
    
    # Calcular estatísticas
    # Em produção, teria lógica para calcular dias esperados, taxa de presença, etc.
    
    return {
        "patient_id": patient_id,
        "period": period,
        "from_date": from_date.isoformat(),
        "to_date": today.isoformat(),
        "presence_count": presence_count,
        "expected_days": 0,  # Placeholder: seria calculado com base no agendamento
        "presence_rate": 0,  # Placeholder: seria calculado com base no agendamento
    }


@router.delete("/{presence_id}", response_model=dict)
async def delete_presence(
    presence_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> dict:
    """
    Remove um registro de presença.
    
    Args:
        presence_id: ID da presença
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Mensagem de confirmação
        
    Raises:
        HTTPException: Se a presença não for encontrada ou o usuário não tiver permissão
    """
    # Verificar se o usuário é admin
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permissão insuficiente para remover presenças"
        )
    
    # Buscar a presença
    query = select(Presence).where(Presence.id == presence_id)
    result = await db.execute(query)
    presence = result.scalars().first()
    
    if not presence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Presença com ID {presence_id} não encontrada"
        )
    
    # Remover a presença
    await db.delete(presence)
    await db.commit()
    
    return {"detail": f"Presença com ID {presence_id} removida com sucesso"}