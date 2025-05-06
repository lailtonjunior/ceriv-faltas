import logging
import os
import json
from typing import Dict, Any, List, Optional, Union
from datetime import datetime

import firebase_admin
from firebase_admin import credentials, messaging
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Content, Email
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Patient, User, Notification

# Configuração de logging
logger = logging.getLogger(__name__)

# Inicializar Firebase (se estiver configurado)
try:
    if os.getenv("FIREBASE_CREDENTIALS_PATH"):
        cred = credentials.Certificate(os.getenv("FIREBASE_CREDENTIALS_PATH"))
        firebase_admin.initialize_app(cred)
        logger.info("Firebase inicializado com sucesso")
    else:
        logger.warning("Caminho para credenciais do Firebase não configurado")
except Exception as e:
    logger.error(f"Erro ao inicializar Firebase: {e}")


class NotificationService:
    """Serviço para envio de notificações (push, email e banco de dados)."""
    
    @staticmethod
    async def send_notification(
        db: AsyncSession,
        title: str,
        message: str,
        notification_type: str,
        data: Optional[Dict[str, Any]] = None,
        user_id: Optional[int] = None,
        patient_id: Optional[int] = None,
        send_push: bool = True,
        send_email: bool = True
    ) -> Optional[Notification]:
        """
        Envia uma notificação para um usuário ou paciente.
        
        Args:
            db: Sessão do banco de dados
            title: Título da notificação
            message: Mensagem da notificação
            notification_type: Tipo de notificação (appointment, absence, badge, system)
            data: Dados adicionais para a notificação
            user_id: ID do usuário (se destinado a um usuário)
            patient_id: ID do paciente (se destinado a um paciente)
            send_push: Se deve enviar notificação push
            send_email: Se deve enviar email
            
        Returns:
            Objeto de notificação criado ou None em caso de erro
        """
        try:
            # Validar parâmetros
            if not user_id and not patient_id:
                logger.error("Erro ao enviar notificação: user_id ou patient_id devem ser fornecidos")
                return None
            
            # Criar registro no banco de dados
            notification = Notification(
                title=title,
                message=message,
                type=notification_type,
                user_id=user_id,
                patient_id=patient_id,
                data=data
            )
            
            db.add(notification)
            await db.commit()
            await db.refresh(notification)
            
            # Enviar notificação push
            if send_push:
                if patient_id:
                    await NotificationService._send_patient_push(db, patient_id, title, message, data)
                if user_id:
                    await NotificationService._send_user_push(db, user_id, title, message, data)
            
            # Enviar email
            if send_email:
                if patient_id:
                    await NotificationService._send_patient_email(db, patient_id, title, message, notification_type)
                if user_id:
                    await NotificationService._send_user_email(db, user_id, title, message, notification_type)
            
            logger.info(f"Notificação {notification.id} enviada com sucesso")
            return notification
            
        except Exception as e:
            logger.error(f"Erro ao enviar notificação: {e}")
            return None

    @staticmethod
    async def _send_patient_push(
        db: AsyncSession,
        patient_id: int, 
        title: str, 
        message: str, 
        data: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Envia notificação push para um paciente.
        
        Args:
            db: Sessão do banco de dados
            patient_id: ID do paciente
            title: Título da notificação
            message: Mensagem da notificação
            data: Dados adicionais para a notificação
            
        Returns:
            True se a notificação foi enviada com sucesso
        """
        try:
            # Buscar o token FCM do paciente
            query = select(Patient).where(Patient.id == patient_id)
            result = await db.execute(query)
            patient = result.scalars().first()
            
            if not patient or not patient.fcm_token:
                logger.warning(f"Paciente {patient_id} não tem token FCM")
                return False
            
            # Preparar mensagem
            push_message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=message
                ),
                data={
                    "type": data.get("type", "notification"),
                    "timestamp": datetime.now().isoformat(),
                    **{k: str(v) for k, v in (data or {}).items()}
                },
                token=patient.fcm_token,
            )
            
            # Enviar notificação
            response = messaging.send(push_message)
            logger.info(f"Notificação push enviada para paciente {patient_id}: {response}")
            return True
            
        except Exception as e:
            logger.error(f"Erro ao enviar notificação push para paciente {patient_id}: {e}")
            return False

    @staticmethod
    async def _send_user_push(
        db: AsyncSession,
        user_id: int, 
        title: str, 
        message: str, 
        data: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Envia notificação push para um usuário.
        
        Args:
            db: Sessão do banco de dados
            user_id: ID do usuário
            title: Título da notificação
            message: Mensagem da notificação
            data: Dados adicionais para a notificação
            
        Returns:
            True se a notificação foi enviada com sucesso
        """
        try:
            # Buscar o token FCM do usuário
            query = select(User).where(User.id == user_id)
            result = await db.execute(query)
            user = result.scalars().first()
            
            if not user or not user.fcm_token:
                logger.warning(f"Usuário {user_id} não tem token FCM")
                return False
            
            # Preparar mensagem
            push_message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=message
                ),
                data={
                    "type": data.get("type", "notification"),
                    "timestamp": datetime.now().isoformat(),
                    **{k: str(v) for k, v in (data or {}).items()}
                },
                token=user.fcm_token,
            )
            
            # Enviar notificação
            response = messaging.send(push_message)
            logger.info(f"Notificação push enviada para usuário {user_id}: {response}")
            return True
            
        except Exception as e:
            logger.error(f"Erro ao enviar notificação push para usuário {user_id}: {e}")
            return False

    @staticmethod
    async def _send_patient_email(
        db: AsyncSession,
        patient_id: int, 
        title: str, 
        message: str, 
        notification_type: str
    ) -> bool:
        """
        Envia email para um paciente.
        
        Args:
            db: Sessão do banco de dados
            patient_id: ID do paciente
            title: Título do email
            message: Conteúdo do email
            notification_type: Tipo de notificação
            
        Returns:
            True se o email foi enviado com sucesso
        """
        try:
            # Buscar o paciente
            query = select(Patient).where(Patient.id == patient_id)
            result = await db.execute(query)
            patient = result.scalars().first()
            
            if not patient or not patient.email:
                logger.warning(f"Paciente {patient_id} não tem email")
                return False
            
            # Configurar SendGrid
            sg_api_key = os.getenv("SENDGRID_API_KEY")
            if not sg_api_key:
                logger.error("API key do SendGrid não configurada")
                return False
            
            from_email = Email(os.getenv("EMAIL_FROM", "noreply@ceriv.org.br"))
            from_name = os.getenv("EMAIL_NAME", "CER IV App")
            to_email = patient.email
            
            # Criar email
            content = Content("text/html", NotificationService._generate_email_html(
                title, message, patient.name, notification_type
            ))
            
            mail = Mail(from_email, to_email, title, content)
            
            # Enviar email
            sg = SendGridAPIClient(sg_api_key)
            response = sg.client.mail.send.post(request_body=mail.get())
            
            logger.info(f"Email enviado para paciente {patient_id}: {response.status_code}")
            return response.status_code == 202
            
        except Exception as e:
            logger.error(f"Erro ao enviar email para paciente {patient_id}: {e}")
            return False

    @staticmethod
    async def _send_user_email(
        db: AsyncSession,
        user_id: int, 
        title: str, 
        message: str, 
        notification_type: str
    ) -> bool:
        """
        Envia email para um usuário.
        
        Args:
            db: Sessão do banco de dados
            user_id: ID do usuário
            title: Título do email
            message: Conteúdo do email
            notification_type: Tipo de notificação
            
        Returns:
            True se o email foi enviado com sucesso
        """
        try:
            # Buscar o usuário
            query = select(User).where(User.id == user_id)
            result = await db.execute(query)
            user = result.scalars().first()
            
            if not user or not user.email:
                logger.warning(f"Usuário {user_id} não tem email")
                return False
            
            # Configurar SendGrid
            sg_api_key = os.getenv("SENDGRID_API_KEY")
            if not sg_api_key:
                logger.error("API key do SendGrid não configurada")
                return False
            
            from_email = Email(os.getenv("EMAIL_FROM", "noreply@ceriv.org.br"))
            from_name = os.getenv("EMAIL_NAME", "CER IV App")
            to_email = user.email
            
            # Criar email
            content = Content("text/html", NotificationService._generate_email_html(
                title, message, user.name, notification_type
            ))
            
            mail = Mail(from_email, to_email, title, content)
            
            # Enviar email
            sg = SendGridAPIClient(sg_api_key)
            response = sg.client.mail.send.post(request_body=mail.get())
            
            logger.info(f"Email enviado para usuário {user_id}: {response.status_code}")
            return response.status_code == 202
            
        except Exception as e:
            logger.error(f"Erro ao enviar email para usuário {user_id}: {e}")
            return False

    @staticmethod
    def _generate_email_html(
        title: str, 
        message: str, 
        recipient_name: str, 
        notification_type: str
    ) -> str:
        """
        Gera o HTML para um email de notificação.
        
        Args:
            title: Título do email
            message: Conteúdo do email
            recipient_name: Nome do destinatário
            notification_type: Tipo de notificação
            
        Returns:
            HTML do email
        """
        # Cor do cabeçalho conforme o tipo
        header_color = "#005A9C"  # Padrão azul
        
        if notification_type == "absence":
            header_color = "#FF9800"  # Laranja
        elif notification_type == "badge":
            header_color = "#4CAF50"  # Verde
        elif notification_type == "system":
            header_color = "#9E9E9E"  # Cinza
        
        # Template básico HTML
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{title}</title>
            <style>
                body {{
                    font-family: Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    margin: 0;
                    padding: 0;
                }}
                .container {{
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                }}
                .header {{
                    background-color: {header_color};
                    color: white;
                    padding: 20px;
                    text-align: center;
                }}
                .content {{
                    padding: 20px;
                    background-color: #f5f5f5;
                }}
                .footer {{
                    text-align: center;
                    padding: 20px;
                    font-size: 12px;
                    color: #666;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>{title}</h1>
                </div>
                <div class="content">
                    <p>Olá, {recipient_name},</p>
                    <p>{message}</p>
                    <p>Atenciosamente,<br>Equipe do CER IV</p>
                </div>
                <div class="footer">
                    <p>Esta é uma mensagem automática. Por favor, não responda a este email.</p>
                    <p>© {datetime.now().year} Centro Especializado em Reabilitação - CER IV</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        return html

    @staticmethod
    async def get_notifications(
        db: AsyncSession,
        user_id: Optional[int] = None,
        patient_id: Optional[int] = None,
        limit: int = 20,
        offset: int = 0,
        unread_only: bool = False
    ) -> List[Notification]:
        """
        Retorna as notificações de um usuário ou paciente.
        
        Args:
            db: Sessão do banco de dados
            user_id: ID do usuário
            patient_id: ID do paciente
            limit: Número máximo de notificações
            offset: Número de notificações a pular
            unread_only: Se deve retornar apenas notificações não lidas
            
        Returns:
            Lista de notificações
        """
        try:
            query = select(Notification)
            
            if user_id:
                query = query.where(Notification.user_id == user_id)
            
            if patient_id:
                query = query.where(Notification.patient_id == patient_id)
            
            if unread_only:
                query = query.where(Notification.read == False)
            
            query = query.order_by(Notification.created_at.desc()).limit(limit).offset(offset)
            
            result = await db.execute(query)
            notifications = result.scalars().all()
            
            return notifications
            
        except Exception as e:
            logger.error(f"Erro ao buscar notificações: {e}")
            return []

    @staticmethod
    async def mark_as_read(
        db: AsyncSession,
        notification_id: int
    ) -> bool:
        """
        Marca uma notificação como lida.
        
        Args:
            db: Sessão do banco de dados
            notification_id: ID da notificação
            
        Returns:
            True se a notificação foi marcada como lida
        """
        try:
            query = select(Notification).where(Notification.id == notification_id)
            result = await db.execute(query)
            notification = result.scalars().first()
            
            if not notification:
                return False
            
            notification.read = True
            notification.read_at = datetime.now()
            
            await db.commit()
            return True
            
        except Exception as e:
            logger.error(f"Erro ao marcar notificação como lida: {e}")
            return False
    
    @staticmethod
    async def mark_all_as_read(
        db: AsyncSession,
        user_id: Optional[int] = None,
        patient_id: Optional[int] = None
    ) -> int:
        """
        Marca todas as notificações de um usuário ou paciente como lidas.
        
        Args:
            db: Sessão do banco de dados
            user_id: ID do usuário
            patient_id: ID do paciente
            
        Returns:
            Número de notificações marcadas como lidas
        """
        try:
            if not user_id and not patient_id:
                return 0
            
            # Buscar notificações não lidas
            query = select(Notification).where(Notification.read == False)
            
            if user_id:
                query = query.where(Notification.user_id == user_id)
            
            if patient_id:
                query = query.where(Notification.patient_id == patient_id)
            
            result = await db.execute(query)
            notifications = result.scalars().all()
            
            # Marcar como lidas
            now = datetime.now()
            count = 0
            
            for notification in notifications:
                notification.read = True
                notification.read_at = now
                count += 1
            
            await db.commit()
            return count
            
        except Exception as e:
            logger.error(f"Erro ao marcar todas notificações como lidas: {e}")
            return 0


# Funções de conveniência para uso direto
async def send_notification(
    db: AsyncSession,
    title: str,
    message: str,
    notification_type: str,
    data: Optional[Dict[str, Any]] = None,
    user_id: Optional[int] = None,
    patient_id: Optional[int] = None,
    send_push: bool = True,
    send_email: bool = True
) -> Optional[Notification]:
    """Wrapper para enviar uma notificação."""
    return await NotificationService.send_notification(
        db, title, message, notification_type, data, user_id, patient_id, send_push, send_email
    )


async def send_patient_notification(
    db: AsyncSession,
    patient_id: int,
    title: str,
    message: str,
    notification_type: str,
    data: Optional[Dict[str, Any]] = None,
    send_push: bool = True,
    send_email: bool = True
) -> Optional[Notification]:
    """Wrapper para enviar uma notificação para um paciente."""
    return await NotificationService.send_notification(
        db, title, message, notification_type, data, None, patient_id, send_push, send_email
    )


async def send_user_notification(
    db: AsyncSession,
    user_id: int,
    title: str,
    message: str,
    notification_type: str,
    data: Optional[Dict[str, Any]] = None,
    send_push: bool = True,
    send_email: bool = True
) -> Optional[Notification]:
    """Wrapper para enviar uma notificação para um usuário."""
    return await NotificationService.send_notification(
        db, title, message, notification_type, data, user_id, None, send_push, send_email
    )