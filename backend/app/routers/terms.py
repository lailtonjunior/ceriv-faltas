import os
import logging
import uuid
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Form, BackgroundTasks
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import TermVersion, TermAcceptance, Patient, User
from app.schemas import (
    TermVersionCreate, TermVersionOut, TermVersionUpdate,
    TermAcceptanceCreate, TermAcceptanceOut
)
from app.services.security import get_current_user
from app.services.term_pdf import generate_term_pdf

# Configuração de logging
logger = logging.getLogger(__name__)

# Criar router
router = APIRouter(prefix="/terms", tags=["terms"])

# Diretório para armazenar assinaturas e PDFs
UPLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads")
SIGNATURES_DIR = os.path.join(UPLOADS_DIR, "signatures")
TERMS_DIR = os.path.join(UPLOADS_DIR, "terms")

# Criar diretórios se não existirem
os.makedirs(SIGNATURES_DIR, exist_ok=True)
os.makedirs(TERMS_DIR, exist_ok=True)


@router.post("/versions", response_model=TermVersionOut)
async def create_term_version(
    term_version: TermVersionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> TermVersion:
    """
    Cria uma nova versão de termo.
    
    Args:
        term_version: Dados da versão do termo
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Versão do termo criada
        
    Raises:
        HTTPException: Se a versão já existir ou o usuário não tiver permissão
    """
    # Verificar permissão
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permissão insuficiente para criar versões de termos"
        )
    
    # Verificar se a versão já existe
    query = select(TermVersion).where(TermVersion.version == term_version.version)
    result = await db.execute(query)
    existing_version = result.scalars().first()
    
    if existing_version:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Versão {term_version.version} já existe"
        )
    
    # Criar nova versão
    db_term_version = TermVersion(
        version=term_version.version,
        title=term_version.title,
        content=term_version.content,
        is_active=term_version.is_active,
        author_id=current_user.id
    )
    
    db.add(db_term_version)
    await db.commit()
    await db.refresh(db_term_version)
    
    return db_term_version


@router.get("/versions", response_model=List[TermVersionOut])
async def read_term_versions(
    skip: int = 0,
    limit: int = 100,
    active_only: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> List[TermVersion]:
    """
    Retorna a lista de versões de termos.
    
    Args:
        skip: Número de registros para pular
        limit: Número máximo de registros
        active_only: Se deve retornar apenas versões ativas
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Lista de versões de termos
    """
    query = select(TermVersion)
    
    if active_only:
        query = query.where(TermVersion.is_active == True)
    
    query = query.order_by(TermVersion.created_at.desc()).offset(skip).limit(limit)
    
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/versions/latest", response_model=TermVersionOut)
async def read_latest_term_version(
    db: AsyncSession = Depends(get_db)
) -> TermVersion:
    """
    Retorna a versão mais recente do termo ativo.
    
    Args:
        db: Sessão do banco de dados
        
    Returns:
        Versão mais recente do termo
        
    Raises:
        HTTPException: Se não houver versão ativa
    """
    query = select(TermVersion).where(
        TermVersion.is_active == True
    ).order_by(
        TermVersion.created_at.desc()
    ).limit(1)
    
    result = await db.execute(query)
    term_version = result.scalars().first()
    
    if not term_version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nenhuma versão ativa do termo encontrada"
        )
    
    return term_version


@router.get("/versions/{version_id}", response_model=TermVersionOut)
async def read_term_version(
    version_id: int,
    db: AsyncSession = Depends(get_db)
) -> TermVersion:
    """
    Retorna uma versão específica do termo.
    
    Args:
        version_id: ID da versão
        db: Sessão do banco de dados
        
    Returns:
        Versão do termo
        
    Raises:
        HTTPException: Se a versão não for encontrada
    """
    query = select(TermVersion).where(TermVersion.id == version_id)
    result = await db.execute(query)
    term_version = result.scalars().first()
    
    if not term_version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Versão do termo com ID {version_id} não encontrada"
        )
    
    return term_version


@router.put("/versions/{version_id}", response_model=TermVersionOut)
async def update_term_version(
    version_id: int,
    term_version: TermVersionUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> TermVersion:
    """
    Atualiza uma versão do termo.
    
    Args:
        version_id: ID da versão
        term_version: Dados para atualização
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Versão atualizada
        
    Raises:
        HTTPException: Se a versão não for encontrada ou o usuário não tiver permissão
    """
    # Verificar permissão
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permissão insuficiente para atualizar versões de termos"
        )
    
    # Buscar a versão
    query = select(TermVersion).where(TermVersion.id == version_id)
    result = await db.execute(query)
    db_term_version = result.scalars().first()
    
    if not db_term_version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Versão do termo com ID {version_id} não encontrada"
        )
    
    # Atualizar campos
    if term_version.title is not None:
        db_term_version.title = term_version.title
    
    if term_version.content is not None:
        db_term_version.content = term_version.content
    
    if term_version.is_active is not None:
        db_term_version.is_active = term_version.is_active
    
    await db.commit()
    await db.refresh(db_term_version)
    
    return db_term_version


@router.post("/acceptances", response_model=TermAcceptanceOut)
async def create_term_acceptance(
    background_tasks: BackgroundTasks,
    patient_id: int = Form(...),
    term_version_id: int = Form(...),
    signature_text: str = Form(...),
    guardian_signature_text: Optional[str] = Form(None),
    ip_address: Optional[str] = Form(None),
    user_agent: Optional[str] = Form(None),
    signature_file: Optional[UploadFile] = File(None),
    guardian_signature_file: Optional[UploadFile] = File(None),
    db: AsyncSession = Depends(get_db)
) -> TermAcceptance:
    """
    Registra a aceitação de um termo por um paciente.
    
    Args:
        background_tasks: Tarefas em segundo plano
        patient_id: ID do paciente
        term_version_id: ID da versão do termo
        signature_text: Assinatura por extenso
        guardian_signature_text: Assinatura por extenso do responsável
        ip_address: Endereço IP
        user_agent: User Agent
        signature_file: Arquivo com assinatura manuscrita
        guardian_signature_file: Arquivo com assinatura manuscrita do responsável
        db: Sessão do banco de dados
        
    Returns:
        Registro de aceitação
        
    Raises:
        HTTPException: Se o paciente ou versão não forem encontrados
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
    
    # Verificar se a versão do termo existe
    term_query = select(TermVersion).where(TermVersion.id == term_version_id)
    term_result = await db.execute(term_query)
    term_version = term_result.scalars().first()
    
    if not term_version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Versão do termo com ID {term_version_id} não encontrada"
        )
    
    # Salvar assinatura manuscrita, se fornecida
    signature_url = None
    guardian_signature_url = None
    
    if signature_file:
        try:
            # Gerar nome de arquivo único
            filename = f"{uuid.uuid4()}.png"
            filepath = os.path.join(SIGNATURES_DIR, filename)
            
            # Salvar arquivo
            with open(filepath, "wb") as f:
                f.write(await signature_file.read())
            
            signature_url = f"/uploads/signatures/{filename}"
            
        except Exception as e:
            logger.error(f"Erro ao salvar assinatura: {e}")
    
    if guardian_signature_file and patient.is_minor:
        try:
            # Gerar nome de arquivo único
            filename = f"{uuid.uuid4()}.png"
            filepath = os.path.join(SIGNATURES_DIR, filename)
            
            # Salvar arquivo
            with open(filepath, "wb") as f:
                f.write(await guardian_signature_file.read())
            
            guardian_signature_url = f"/uploads/signatures/{filename}"
            
        except Exception as e:
            logger.error(f"Erro ao salvar assinatura do responsável: {e}")
    
    # Criar registro de aceitação
    term_acceptance = TermAcceptance(
        patient_id=patient_id,
        term_version_id=term_version_id,
        ip_address=ip_address,
        user_agent=user_agent,
        signature_url=signature_url,
        signature_text=signature_text,
        guardian_signature_url=guardian_signature_url,
        guardian_signature_text=guardian_signature_text
    )
    
    db.add(term_acceptance)
    await db.commit()
    await db.refresh(term_acceptance)
    
    # Gerar PDF em segundo plano
    background_tasks.add_task(
        generate_term_pdf_file,
        db,
        term_acceptance.id,
        patient,
        term_version,
        signature_url,
        signature_text,
        guardian_signature_url,
        guardian_signature_text
    )
    
    return term_acceptance


@router.get("/acceptances", response_model=List[TermAcceptanceOut])
async def read_term_acceptances(
    patient_id: Optional[int] = None,
    term_version_id: Optional[int] = None,
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> List[TermAcceptance]:
    """
    Retorna a lista de aceitações de termos.
    
    Args:
        patient_id: ID do paciente para filtrar
        term_version_id: ID da versão para filtrar
        skip: Número de registros para pular
        limit: Número máximo de registros
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Lista de aceitações de termos
    """
    query = select(TermAcceptance)
    
    # Aplicar filtros
    if patient_id:
        query = query.where(TermAcceptance.patient_id == patient_id)
    
    if term_version_id:
        query = query.where(TermAcceptance.term_version_id == term_version_id)
    
    query = query.order_by(TermAcceptance.accepted_at.desc()).offset(skip).limit(limit)
    
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/acceptances/{acceptance_id}", response_model=TermAcceptanceOut)
async def read_term_acceptance(
    acceptance_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> TermAcceptance:
    """
    Retorna uma aceitação específica.
    
    Args:
        acceptance_id: ID da aceitação
        db: Sessão do banco de dados
        current_user: Usuário atual
        
    Returns:
        Aceitação do termo
        
    Raises:
        HTTPException: Se a aceitação não for encontrada
    """
    query = select(TermAcceptance).where(TermAcceptance.id == acceptance_id)
    result = await db.execute(query)
    term_acceptance = result.scalars().first()
    
    if not term_acceptance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aceitação de termo com ID {acceptance_id} não encontrada"
        )
    
    return term_acceptance


@router.get("/acceptances/{acceptance_id}/pdf")
async def download_acceptance_pdf(
    acceptance_id: int,
    db: AsyncSession = Depends(get_db)
) -> FileResponse:
    """
    Retorna o PDF de uma aceitação de termo.
    
    Args:
        acceptance_id: ID da aceitação
        db: Sessão do banco de dados
        
    Returns:
        Arquivo PDF
        
    Raises:
        HTTPException: Se a aceitação não for encontrada ou o PDF não existir
    """
    # Buscar a aceitação
    query = select(TermAcceptance).where(TermAcceptance.id == acceptance_id)
    result = await db.execute(query)
    term_acceptance = result.scalars().first()
    
    if not term_acceptance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aceitação de termo com ID {acceptance_id} não encontrada"
        )
    
    # Verificar se o PDF existe
    if not term_acceptance.pdf_url:
        # Tentar gerar o PDF
        try:
            # Buscar paciente
            patient_query = select(Patient).where(Patient.id == term_acceptance.patient_id)
            patient_result = await db.execute(patient_query)
            patient = patient_result.scalars().first()
            
            # Buscar versão do termo
            term_query = select(TermVersion).where(TermVersion.id == term_acceptance.term_version_id)
            term_result = await db.execute(term_query)
            term_version = term_result.scalars().first()
            
            # Gerar PDF
            pdf_url = await generate_term_pdf_file(
                db,
                acceptance_id,
                patient,
                term_version,
                term_acceptance.signature_url,
                term_acceptance.signature_text,
                term_acceptance.guardian_signature_url,
                term_acceptance.guardian_signature_text
            )
            
            if not pdf_url:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Não foi possível gerar o PDF do termo"
                )
                
        except Exception as e:
            logger.error(f"Erro ao gerar PDF para aceitação {acceptance_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Erro ao gerar PDF do termo"
            )
    
    # Caminho completo do arquivo
    if term_acceptance.pdf_url:
        pdf_path = os.path.join(UPLOADS_DIR, term_acceptance.pdf_url.lstrip("/uploads/"))
        
        if os.path.exists(pdf_path):
            # Nome do arquivo para download
            filename = f"termo_aceitacao_{acceptance_id}.pdf"
            
            return FileResponse(
                path=pdf_path,
                filename=filename,
                media_type="application/pdf"
            )
    
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="PDF do termo não encontrado"
    )


@router.get("/versions/{version_id}/pdf")
async def generate_version_pdf(
    version_id: int,
    db: AsyncSession = Depends(get_db)
) -> StreamingResponse:
    """
    Gera um PDF para uma versão do termo (sem assinatura).
    
    Args:
        version_id: ID da versão
        db: Sessão do banco de dados
        
    Returns:
        PDF da versão do termo
        
    Raises:
        HTTPException: Se a versão não for encontrada
    """
    # Buscar a versão
    query = select(TermVersion).where(TermVersion.id == version_id)
    result = await db.execute(query)
    term_version = result.scalars().first()
    
    if not term_version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Versão do termo com ID {version_id} não encontrada"
        )
    
    try:
        # Gerar PDF sem assinatura
        pdf_buffer = generate_term_pdf(
            term_title=term_version.title,
            term_content=term_version.content,
            patient_name="[Nome do Paciente]",
            patient_cpf="[CPF do Paciente]",
            term_version=term_version.version
        )
        
        # Configurar resposta
        filename = f"termo_{term_version.version.replace('.', '_')}.pdf"
        
        return StreamingResponse(
            iter([pdf_buffer.getvalue()]),
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
        
    except Exception as e:
        logger.error(f"Erro ao gerar PDF para versão {version_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao gerar PDF do termo"
        )


async def generate_term_pdf_file(
    db: AsyncSession,
    acceptance_id: int,
    patient: Patient,
    term_version: TermVersion,
    signature_url: Optional[str] = None,
    signature_text: Optional[str] = None,
    guardian_signature_url: Optional[str] = None,
    guardian_signature_text: Optional[str] = None
) -> Optional[str]:
    """
    Gera um arquivo PDF para uma aceitação de termo e atualiza o registro.
    
    Args:
        db: Sessão do banco de dados
        acceptance_id: ID da aceitação
        patient: Objeto do paciente
        term_version: Objeto da versão do termo
        signature_url: URL da assinatura
        signature_text: Assinatura por extenso
        guardian_signature_url: URL da assinatura do responsável
        guardian_signature_text: Assinatura por extenso do responsável
        
    Returns:
        URL do PDF gerado ou None em caso de erro
    """
    try:
        # Preparar caminhos de assinatura
        signature_path = None
        guardian_signature_path = None
        
        if signature_url:
            signature_path = os.path.join(UPLOADS_DIR, signature_url.lstrip("/uploads/"))
            if not os.path.exists(signature_path):
                signature_path = None
        
        if guardian_signature_url:
            guardian_signature_path = os.path.join(UPLOADS_DIR, guardian_signature_url.lstrip("/uploads/"))
            if not os.path.exists(guardian_signature_path):
                guardian_signature_path = None
        
        # Obter informações do responsável, se for menor de idade
        guardian_name = None
        guardian_cpf = None
        
        if patient.is_minor:
            # Em um cenário real, buscaria o responsável do banco de dados
            # Aqui simplificado para demonstração
            guardian_query = select(patient.guardians)
            guardian_result = await db.execute(guardian_query)
            guardians = guardian_result.scalars().all()
            
            if guardians:
                guardian = guardians[0]
                guardian_name = guardian.name
                guardian_cpf = guardian.cpf
        
        # Gerar PDF
        pdf_buffer = generate_term_pdf(
            term_title=term_version.title,
            term_content=term_version.content,
            patient_name=patient.name,
            patient_cpf=patient.cpf,
            patient_signature_path=signature_path,
            patient_signature_text=signature_text or "",
            guardian_name=guardian_name,
            guardian_cpf=guardian_cpf,
            guardian_signature_path=guardian_signature_path,
            guardian_signature_text=guardian_signature_text,
            term_version=term_version.version
        )
        
        # Salvar o PDF
        filename = f"termo_{acceptance_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}.pdf"
        filepath = os.path.join(TERMS_DIR, filename)
        
        with open(filepath, "wb") as f:
            f.write(pdf_buffer.getvalue())
        
        # Atualizar o registro com a URL do PDF
        pdf_url = f"/uploads/terms/{filename}"
        
        # Buscar a aceitação
        query = select(TermAcceptance).where(TermAcceptance.id == acceptance_id)
        result = await db.execute(query)
        term_acceptance = result.scalars().first()
        
        if term_acceptance:
            term_acceptance.pdf_url = pdf_url
            await db.commit()
        
        return pdf_url
        
    except Exception as e:
        logger.error(f"Erro ao gerar PDF para aceitação {acceptance_id}: {e}")
        return None