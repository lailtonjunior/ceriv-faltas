import logging
import datetime
from typing import List, Dict, Any, Optional, Tuple
from sqlalchemy import func, select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Patient, Presence, Absence, Badge, PatientBadge
from app.services.notifications import send_patient_notification

# Configuração de logging
logger = logging.getLogger(__name__)


class GamificationService:
    """
    Serviço para gerenciar a gamificação (badges, pontos, rankings).
    """

    @staticmethod
    async def check_presence_badges(db: AsyncSession, patient_id: int) -> List[Dict[str, Any]]:
        """
        Verifica e atribui badges relacionados à presença.
        
        Args:
            db: Sessão do banco de dados
            patient_id: ID do paciente
            
        Returns:
            Lista de badges atribuídos
        """
        logger.info(f"Verificando badges de presença para paciente {patient_id}")
        
        # Obter o paciente
        patient_query = select(Patient).where(Patient.id == patient_id)
        result = await db.execute(patient_query)
        patient = result.scalars().first()
        
        if not patient:
            logger.warning(f"Paciente {patient_id} não encontrado ao verificar badges")
            return []
        
        # Obter presenças do paciente
        presences_query = select(Presence).where(Presence.patient_id == patient_id)
        result = await db.execute(presences_query)
        presences = result.scalars().all()
        
        # Obter faltas do paciente
        absences_query = select(Absence).where(Absence.patient_id == patient_id)
        result = await db.execute(absences_query)
        absences = result.scalars().all()
        
        # Obter badges já conquistados
        badges_query = select(PatientBadge).where(PatientBadge.patient_id == patient_id)
        result = await db.execute(badges_query)
        patient_badges = result.scalars().all()
        earned_badge_ids = [pb.badge_id for pb in patient_badges]
        
        # Obter todos os badges disponíveis
        badges_query = select(Badge).where(Badge.is_active == True)
        result = await db.execute(badges_query)
        all_badges = result.scalars().all()
        
        # Lista para armazenar novos badges
        new_badges = []
        
        # Organizar presenças por mês
        today = datetime.datetime.now().date()
        current_month = today.replace(day=1)
        
        # Presenças no mês atual
        current_month_presences = [
            p for p in presences 
            if p.date.date().replace(day=1) == current_month
        ]
        
        # Verificar badge "Sem falta no mês"
        no_absence_month_badge = next(
            (b for b in all_badges if b.name == "Sem falta no mês" and b.id not in earned_badge_ids),
            None
        )
        
        if no_absence_month_badge:
            # Verificar se o mês anterior está completo sem faltas
            last_month = (today.replace(day=1) - datetime.timedelta(days=1)).replace(day=1)
            last_month_absences = [
                a for a in absences 
                if a.date.date().replace(day=1) == last_month
            ]
            
            if not last_month_absences and any(
                p.date.date().replace(day=1) == last_month for p in presences
            ):
                # Atribuir badge
                await GamificationService._award_badge(
                    db, patient_id, no_absence_month_badge.id, 
                    f"Parabéns! Você completou o mês de {last_month.strftime('%B/%Y')} sem faltas."
                )
                new_badges.append({
                    "id": no_absence_month_badge.id,
                    "name": no_absence_month_badge.name,
                    "description": no_absence_month_badge.description,
                    "points": no_absence_month_badge.points
                })
        
        # Verificar badge "100% presença 3 meses"
        perfect_3m_badge = next(
            (b for b in all_badges if b.name == "100% presença 3 meses" and b.id not in earned_badge_ids),
            None
        )
        
        if perfect_3m_badge:
            # Verificar três meses consecutivos sem faltas
            has_perfect_attendance = await GamificationService._check_perfect_attendance(
                db, patient_id, months=3
            )
            
            if has_perfect_attendance:
                # Atribuir badge
                await GamificationService._award_badge(
                    db, patient_id, perfect_3m_badge.id, 
                    "Parabéns! Você manteve 100% de presença por 3 meses consecutivos."
                )
                new_badges.append({
                    "id": perfect_3m_badge.id,
                    "name": perfect_3m_badge.name,
                    "description": perfect_3m_badge.description,
                    "points": perfect_3m_badge.points
                })
        
        # Verificar outros badges (exemplos)
        # Badge: Primeira presença
        first_presence_badge = next(
            (b for b in all_badges if b.name == "Primeira presença" and b.id not in earned_badge_ids),
            None
        )
        
        if first_presence_badge and presences:
            # Atribuir badge
            await GamificationService._award_badge(
                db, patient_id, first_presence_badge.id, 
                "Parabéns! Você registrou sua primeira presença no CER IV."
            )
            new_badges.append({
                "id": first_presence_badge.id,
                "name": first_presence_badge.name,
                "description": first_presence_badge.description,
                "points": first_presence_badge.points
            })
        
        return new_badges

    @staticmethod
    async def _check_perfect_attendance(db: AsyncSession, patient_id: int, months: int = 3) -> bool:
        """
        Verifica se o paciente tem presença perfeita por um número específico de meses.
        
        Args:
            db: Sessão do banco de dados
            patient_id: ID do paciente
            months: Número de meses para verificar
            
        Returns:
            True se o paciente tiver presença perfeita no período
        """
        today = datetime.datetime.now().date()
        
        # Calcular a data de início (n meses atrás)
        start_date = today.replace(day=1)
        for _ in range(months):
            # Voltar para o mês anterior
            start_date = (start_date - datetime.timedelta(days=1)).replace(day=1)
        
        # Consultar faltas no período
        absences_query = select(Absence).where(
            Absence.patient_id == patient_id,
            Absence.date >= start_date,
            Absence.date < today
        )
        result = await db.execute(absences_query)
        absences = result.scalars().all()
        
        # Se não houver faltas, verificar se há registros de presença para cada mês
        if not absences:
            # Consultar presenças no período
            presences_query = select(Presence).where(
                Presence.patient_id == patient_id,
                Presence.date >= start_date,
                Presence.date < today
            )
            result = await db.execute(presences_query)
            presences = result.scalars().all()
            
            # Agrupar presenças por mês
            presence_months = set()
            for presence in presences:
                month_key = presence.date.strftime("%Y-%m")
                presence_months.add(month_key)
            
            # Verificar se todos os meses têm pelo menos uma presença
            expected_months = set()
            check_date = start_date
            while check_date < today:
                month_key = check_date.strftime("%Y-%m")
                expected_months.add(month_key)
                # Avançar para o próximo mês
                next_month = check_date.month + 1
                next_year = check_date.year
                if next_month > 12:
                    next_month = 1
                    next_year += 1
                check_date = check_date.replace(year=next_year, month=next_month)
            
            return expected_months.issubset(presence_months)
        
        return False

    @staticmethod
    async def _award_badge(db: AsyncSession, patient_id: int, badge_id: int, message: str) -> None:
        """
        Atribui um badge a um paciente.
        
        Args:
            db: Sessão do banco de dados
            patient_id: ID do paciente
            badge_id: ID do badge
            message: Mensagem de notificação
        """
        # Verificar se o paciente já possui o badge
        query = select(PatientBadge).where(
            PatientBadge.patient_id == patient_id,
            PatientBadge.badge_id == badge_id
        )
        result = await db.execute(query)
        existing = result.scalars().first()
        
        if existing:
            logger.info(f"Paciente {patient_id} já possui o badge {badge_id}")
            return
        
        # Criar novo registro
        patient_badge = PatientBadge(
            patient_id=patient_id,
            badge_id=badge_id,
            awarded_at=datetime.datetime.now(),
            notified=False
        )
        
        db.add(patient_badge)
        await db.commit()
        await db.refresh(patient_badge)
        
        logger.info(f"Badge {badge_id} atribuído ao paciente {patient_id}")
        
        # Enviar notificação
        try:
            # Obter detalhes do badge
            badge_query = select(Badge).where(Badge.id == badge_id)
            result = await db.execute(badge_query)
            badge = result.scalars().first()
            
            if badge:
                title = f"Nova conquista: {badge.name}"
                message = message or badge.description or "Parabéns por sua nova conquista!"
                
                await send_patient_notification(
                    db, 
                    patient_id, 
                    title, 
                    message, 
                    "badge",
                    {
                        "badge_id": badge_id,
                        "badge_name": badge.name,
                        "points": badge.points,
                        "icon_url": badge.icon_url
                    }
                )
                
                # Marcar como notificado
                patient_badge.notified = True
                await db.commit()
        except Exception as e:
            logger.error(f"Erro ao enviar notificação de badge: {e}")

    @staticmethod
    async def get_patient_badges(db: AsyncSession, patient_id: int) -> List[Dict[str, Any]]:
        """
        Retorna os badges conquistados por um paciente.
        
        Args:
            db: Sessão do banco de dados
            patient_id: ID do paciente
            
        Returns:
            Lista de badges do paciente
        """
        # Consultar badges do paciente com informações do badge
        query = select(PatientBadge, Badge).join(
            Badge, PatientBadge.badge_id == Badge.id
        ).where(
            PatientBadge.patient_id == patient_id
        ).order_by(
            PatientBadge.awarded_at.desc()
        )
        
        result = await db.execute(query)
        patient_badges = result.all()
        
        badges_list = []
        for pb, badge in patient_badges:
            badges_list.append({
                "id": badge.id,
                "name": badge.name,
                "description": badge.description,
                "icon_url": badge.icon_url,
                "points": badge.points,
                "category": badge.category,
                "awarded_at": pb.awarded_at.isoformat()
            })
        
        return badges_list

    @staticmethod
    async def get_patient_points(db: AsyncSession, patient_id: int) -> int:
        """
        Calcula o total de pontos de um paciente.
        
        Args:
            db: Sessão do banco de dados
            patient_id: ID do paciente
            
        Returns:
            Total de pontos
        """
        # Consultar badges do paciente
        query = select(Badge).join(
            PatientBadge, PatientBadge.badge_id == Badge.id
        ).where(
            PatientBadge.patient_id == patient_id
        )
        
        result = await db.execute(query)
        badges = result.scalars().all()
        
        # Somar pontos
        total_points = sum(badge.points for badge in badges)
        
        return total_points

    @staticmethod
    async def get_ranking(db: AsyncSession, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Retorna o ranking de pacientes por pontos.
        
        Args:
            db: Sessão do banco de dados
            limit: Número máximo de resultados
            
        Returns:
            Lista de pacientes com pontuação
        """
        # Consulta para somar pontos por paciente
        query = select(
            PatientBadge.patient_id,
            func.sum(Badge.points).label('total_points'),
            func.count(PatientBadge.badge_id).label('badges_count')
        ).join(
            Badge, PatientBadge.badge_id == Badge.id
        ).group_by(
            PatientBadge.patient_id
        ).order_by(
            func.sum(Badge.points).desc()
        ).limit(limit)
        
        result = await db.execute(query)
        rankings = result.all()
        
        # Buscar informações dos pacientes
        ranking_list = []
        for patient_id, points, badges_count in rankings:
            # Buscar paciente
            patient_query = select(Patient).where(Patient.id == patient_id)
            patient_result = await db.execute(patient_query)
            patient = patient_result.scalars().first()
            
            if patient:
                ranking_list.append({
                    "patient_id": patient_id,
                    "name": patient.name,
                    "points": points,
                    "badges_count": badges_count
                })
        
        return ranking_list

    @staticmethod
    async def process_daily_badges(db: AsyncSession) -> None:
        """
        Processa badges diariamente para todos os pacientes.
        Deve ser chamado por um agendador (scheduler).
        
        Args:
            db: Sessão do banco de dados
        """
        logger.info("Iniciando processamento diário de badges")
        
        # Buscar todos os pacientes ativos
        query = select(Patient).where(Patient.is_active == True)
        result = await db.execute(query)
        patients = result.scalars().all()
        
        # Processar badges para cada paciente
        for patient in patients:
            try:
                new_badges = await GamificationService.check_presence_badges(db, patient.id)
                if new_badges:
                    logger.info(f"Paciente {patient.id} recebeu {len(new_badges)} novos badges")
            except Exception as e:
                logger.error(f"Erro ao processar badges para paciente {patient.id}: {e}")
        
        logger.info("Processamento diário de badges concluído")


# Função de conveniência para verificação de badges
async def check_patient_badges(db: AsyncSession, patient_id: int) -> List[Dict[str, Any]]:
    """Wrapper para verificar badges de um paciente."""
    return await GamificationService.check_presence_badges(db, patient_id)


# Função de conveniência para obter badges de um paciente
async def get_patient_badges(db: AsyncSession, patient_id: int) -> List[Dict[str, Any]]:
    """Wrapper para obter badges de um paciente."""
    return await GamificationService.get_patient_badges(db, patient_id)


# Função de conveniência para obter pontos de um paciente
async def get_patient_points(db: AsyncSession, patient_id: int) -> int:
    """Wrapper para obter pontos de um paciente."""
    return await GamificationService.get_patient_points(db, patient_id)


# Função de conveniência para obter ranking
async def get_ranking(db: AsyncSession, limit: int = 10) -> List[Dict[str, Any]]:
    """Wrapper para obter ranking de pacientes."""
    return await GamificationService.get_ranking(db, limit)