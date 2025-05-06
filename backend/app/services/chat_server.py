#!/usr/bin/env python
"""
Servidor Socket.IO para chat em tempo real com criptografia ponta-a-ponta.
"""

import os
import sys
import json
import logging
import asyncio
import datetime
from typing import Dict, Any, Optional

import socketio
import uvicorn
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy.future import select

# Adicionar diretório do projeto ao path para importar módulos
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from app.models import Message, Patient, User
from app.services.chat_security import ChatEncryption, KeyManager

# Configuração de logging
logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO")),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("chat_server")

# Configuração do Socket.IO
sio = socketio.AsyncServer(
    async_mode='asgi', 
    cors_allowed_origins=os.getenv("SOCKETIO_CORS_ORIGINS", "*").split(",")
)
app = socketio.ASGIApp(sio)

# Configuração do banco de dados
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://ceriv:ceriv_password@localhost/ceriv_db")
engine = create_async_engine(DATABASE_URL, echo=False)
async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

# Armazenamento em memória para rastreamento de salas e usuários conectados
connected_users = {}  # sid -> {user_id, role}
user_rooms = {}  # user_id -> [conversation_ids]


async def get_session() -> AsyncSession:
    """Cria e retorna uma sessão de banco de dados assíncrona."""
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()


async def save_message(message_data: Dict[str, Any]) -> None:
    """
    Salva uma mensagem no banco de dados.
    
    Args:
        message_data: Dados da mensagem
    """
    try:
        async with async_session() as session:
            # Criar objeto de mensagem
            message = Message(
                conversation_id=message_data.get('conversation_id'),
                patient_id=message_data.get('patient_id'),
                user_id=message_data.get('user_id'),
                sender_type=message_data.get('sender_type'),
                content=message_data.get('content'),
                encrypted=message_data.get('encrypted', True),
                attachment_url=message_data.get('attachment_url'),
                attachment_type=message_data.get('attachment_type'),
            )
            
            session.add(message)
            await session.commit()
            
            logger.info(f"Mensagem salva no banco: {message.id}")
            
    except Exception as e:
        logger.error(f"Erro ao salvar mensagem: {e}")


async def get_conversation_metadata(conversation_id: str) -> Dict[str, Any]:
    """
    Obtém os metadados de uma conversa.
    
    Args:
        conversation_id: ID da conversa
        
    Returns:
        Dicionário com metadados da conversa
    """
    try:
        async with async_session() as session:
            # Buscar a primeira mensagem da conversa para obter os participantes
            query = select(Message).where(Message.conversation_id == conversation_id).limit(1)
            result = await session.execute(query)
            message = result.scalars().first()
            
            if not message:
                return {
                    'conversation_id': conversation_id,
                    'patient_id': None,
                    'staff_id': None,
                    'created_at': None
                }
            
            return {
                'conversation_id': conversation_id,
                'patient_id': message.patient_id,
                'staff_id': message.user_id,
                'created_at': message.created_at
            }
            
    except Exception as e:
        logger.error(f"Erro ao obter metadados da conversa: {e}")
        return {
            'conversation_id': conversation_id,
            'error': str(e)
        }


@sio.event
async def connect(sid, environ):
    """
    Manipula a conexão de um cliente.
    
    Args:
        sid: ID da sessão
        environ: Ambiente WSGI
    """
    logger.info(f"Cliente conectado: {sid}")
    
    # Em uma implementação real, seria feita a validação do token JWT
    # Aqui simplificado para demonstração
    auth_header = environ.get('HTTP_AUTHORIZATION', '')
    if auth_header.startswith('Bearer '):
        token = auth_header[7:]
        # Validar token (simplificado)
        user_id = "123"  # Extraído do token
        role = "staff"   # Extraído do token
        
        connected_users[sid] = {
            'user_id': user_id,
            'role': role
        }
        
        await sio.emit('auth_success', {'user_id': user_id, 'role': role}, room=sid)
        logger.info(f"Usuário autenticado: {user_id} (role: {role})")
    else:
        # Recusar conexão sem autenticação
        return False


@sio.event
async def disconnect(sid):
    """
    Manipula a desconexão de um cliente.
    
    Args:
        sid: ID da sessão
    """
    # Remover das salas
    if sid in connected_users:
        user_id = connected_users[sid]['user_id']
        if user_id in user_rooms:
            for room in user_rooms[user_id]:
                await sio.leave_room(sid, room)
            del user_rooms[user_id]
        
        del connected_users[sid]
    
    logger.info(f"Cliente desconectado: {sid}")


@sio.event
async def join_conversation(sid, data):
    """
    Permite que um cliente entre em uma sala de conversação.
    
    Args:
        sid: ID da sessão
        data: Dados com conversation_id
    """
    if sid not in connected_users:
        await sio.emit('error', {'message': 'Não autenticado'}, room=sid)
        return
    
    conversation_id = data.get('conversation_id')
    if not conversation_id:
        await sio.emit('error', {'message': 'ID de conversação não fornecido'}, room=sid)
        return
    
    user_id = connected_users[sid]['user_id']
    
    # Verificar permissão para acessar a conversa
    # Em produção, verificaria se o usuário tem permissão para acessar a conversa
    
    # Entrar na sala
    await sio.enter_room(sid, conversation_id)
    
    # Rastrear salas do usuário
    if user_id not in user_rooms:
        user_rooms[user_id] = []
    if conversation_id not in user_rooms[user_id]:
        user_rooms[user_id].append(conversation_id)
    
    # Notificar cliente
    await sio.emit('joined_conversation', {
        'conversation_id': conversation_id,
        'timestamp': datetime.datetime.now().isoformat()
    }, room=sid)
    
    logger.info(f"Usuário {user_id} entrou na conversa {conversation_id}")


@sio.event
async def leave_conversation(sid, data):
    """
    Permite que um cliente saia de uma sala de conversação.
    
    Args:
        sid: ID da sessão
        data: Dados com conversation_id
    """
    if sid not in connected_users:
        return
    
    conversation_id = data.get('conversation_id')
    if not conversation_id:
        return
    
    user_id = connected_users[sid]['user_id']
    
    # Sair da sala
    await sio.leave_room(sid, conversation_id)
    
    # Atualizar rastreamento
    if user_id in user_rooms and conversation_id in user_rooms[user_id]:
        user_rooms[user_id].remove(conversation_id)
    
    logger.info(f"Usuário {user_id} saiu da conversa {conversation_id}")


@sio.event
async def send_message(sid, data):
    """
    Processa e encaminha uma mensagem para todos os clientes na sala.
    
    Args:
        sid: ID da sessão
        data: Dados da mensagem
    """
    if sid not in connected_users:
        await sio.emit('error', {'message': 'Não autenticado'}, room=sid)
        return
    
    # Validar dados
    required_fields = ['conversation_id', 'content']
    if not all(field in data for field in required_fields):
        await sio.emit('error', {'message': 'Dados incompletos'}, room=sid)
        return
    
    user_info = connected_users[sid]
    user_id = user_info['user_id']
    role = user_info['role']
    
    # Estruturar mensagem
    message_data = {
        'id': str(uuid.uuid4()),  # ID temporário até salvar no banco
        'conversation_id': data['conversation_id'],
        'content': data['content'],
        'sender_type': role,  # staff ou patient
        'encrypted': data.get('encrypted', True),
        'timestamp': datetime.datetime.now().isoformat(),
    }
    
    # Adicionar campos específicos por tipo de usuário
    if role == 'staff':
        message_data['user_id'] = user_id
        # Buscar o patient_id da conversa
        conversation = await get_conversation_metadata(data['conversation_id'])
        message_data['patient_id'] = conversation.get('patient_id')
    else:  # patient
        message_data['patient_id'] = user_id
        message_data['user_id'] = None  # Pode ser atualizado com o destinatário staff
    
    # Adicionar anexos, se houver
    if 'attachment_url' in data:
        message_data['attachment_url'] = data['attachment_url']
        message_data['attachment_type'] = data.get('attachment_type', 'file')
    
    # Enviar para todos na sala
    await sio.emit('new_message', message_data, room=data['conversation_id'])
    
    # Salvar no banco de dados
    await save_message(message_data)
    
    logger.info(f"Mensagem enviada na conversa {data['conversation_id']} por {user_id}")


@sio.event
async def mark_as_read(sid, data):
    """
    Marca mensagens como lidas.
    
    Args:
        sid: ID da sessão
        data: Dados com message_ids
    """
    if sid not in connected_users:
        await sio.emit('error', {'message': 'Não autenticado'}, room=sid)
        return
    
    message_ids = data.get('message_ids', [])
    if not message_ids:
        await sio.emit('error', {'message': 'IDs de mensagens não fornecidos'}, room=sid)
        return
    
    try:
        async with async_session() as session:
            # Atualizar mensagens
            for message_id in message_ids:
                query = select(Message).where(Message.id == message_id)
                result = await session.execute(query)
                message = result.scalars().first()
                
                if message:
                    message.read = True
                    message.read_at = datetime.datetime.now()
            
            await session.commit()
            
            # Notificar outros clientes
            conversation_id = data.get('conversation_id')
            if conversation_id:
                await sio.emit('messages_read', {
                    'message_ids': message_ids,
                    'user_id': connected_users[sid]['user_id'],
                    'timestamp': datetime.datetime.now().isoformat()
                }, room=conversation_id, skip_sid=sid)
            
            logger.info(f"Mensagens marcadas como lidas: {message_ids}")
            
    except Exception as e:
        logger.error(f"Erro ao marcar mensagens como lidas: {e}")
        await sio.emit('error', {'message': f'Erro ao marcar mensagens: {str(e)}'}, room=sid)


@sio.event
async def user_typing(sid, data):
    """
    Notifica outros usuários que um usuário está digitando.
    
    Args:
        sid: ID da sessão
        data: Dados com conversation_id
    """
    if sid not in connected_users or 'conversation_id' not in data:
        return
    
    conversation_id = data['conversation_id']
    user_id = connected_users[sid]['user_id']
    
    # Notificar outros clientes na sala
    await sio.emit('typing', {
        'user_id': user_id,
        'conversation_id': conversation_id,
        'timestamp': datetime.datetime.now().isoformat()
    }, room=conversation_id, skip_sid=sid)


@sio.event
async def get_conversation_history(sid, data):
    """
    Retorna o histórico de mensagens de uma conversa.
    
    Args:
        sid: ID da sessão
        data: Dados com conversation_id, limit, offset
    """
    if sid not in connected_users:
        await sio.emit('error', {'message': 'Não autenticado'}, room=sid)
        return
    
    conversation_id = data.get('conversation_id')
    if not conversation_id:
        await sio.emit('error', {'message': 'ID de conversação não fornecido'}, room=sid)
        return
    
    limit = data.get('limit', 50)
    offset = data.get('offset', 0)
    
    try:
        async with async_session() as session:
            # Buscar mensagens
            query = select(Message).where(
                Message.conversation_id == conversation_id
            ).order_by(
                Message.created_at.desc()
            ).limit(limit).offset(offset)
            
            result = await session.execute(query)
            messages = result.scalars().all()
            
            # Formatar resultado
            message_list = []
            for msg in messages:
                message_list.append({
                    'id': msg.id,
                    'conversation_id': str(msg.conversation_id),
                    'patient_id': msg.patient_id,
                    'user_id': msg.user_id,
                    'sender_type': msg.sender_type,
                    'content': msg.content,
                    'encrypted': msg.encrypted,
                    'read': msg.read,
                    'read_at': msg.read_at.isoformat() if msg.read_at else None,
                    'attachment_url': msg.attachment_url,
                    'attachment_type': msg.attachment_type,
                    'timestamp': msg.created_at.isoformat()
                })
            
            # Enviar resultado
            await sio.emit('conversation_history', {
                'conversation_id': conversation_id,
                'messages': message_list,
                'total': len(message_list),
                'has_more': len(message_list) == limit
            }, room=sid)
            
            logger.info(f"Histórico enviado para {conversation_id}, {len(message_list)} mensagens")
            
    except Exception as e:
        logger.error(f"Erro ao obter histórico: {e}")
        await sio.emit('error', {'message': f'Erro ao obter histórico: {str(e)}'}, room=sid)


@sio.event
async def get_unread_count(sid, data):
    """
    Retorna o número de mensagens não lidas para um usuário.
    
    Args:
        sid: ID da sessão
        data: Dados opcionais com conversation_id
    """
    if sid not in connected_users:
        await sio.emit('error', {'message': 'Não autenticado'}, room=sid)
        return
    
    user_info = connected_users[sid]
    user_id = user_info['user_id']
    role = user_info['role']
    
    try:
        async with async_session() as session:
            # Definir condição com base no tipo de usuário
            if role == 'staff':
                # Para equipe, contar mensagens enviadas por pacientes
                condition = Message.sender_type == 'patient'
            else:
                # Para pacientes, contar mensagens enviadas pela equipe
                condition = Message.sender_type == 'staff'
            
            # Filtrar por conversa específica, se fornecida
            conversation_id = data.get('conversation_id')
            if conversation_id:
                query = select(func.count()).where(
                    Message.conversation_id == conversation_id,
                    condition,
                    Message.read == False
                )
                
                result = await session.execute(query)
                count = result.scalar()
                
                await sio.emit('unread_count', {
                    'conversation_id': conversation_id,
                    'count': count
                }, room=sid)
            
            else:
                # Contar mensagens não lidas em todas as conversas
                if role == 'staff':
                    # Staff pode gerenciar múltiplos pacientes
                    query = select(
                        Message.conversation_id,
                        func.count()
                    ).where(
                        condition,
                        Message.read == False
                    ).group_by(
                        Message.conversation_id
                    )
                else:
                    # Paciente tem suas próprias conversas
                    query = select(
                        Message.conversation_id,
                        func.count()
                    ).where(
                        Message.patient_id == user_id,
                        condition,
                        Message.read == False
                    ).group_by(
                        Message.conversation_id
                    )
                
                result = await session.execute(query)
                counts = {str(conv_id): count for conv_id, count in result.all()}
                total = sum(counts.values())
                
                await sio.emit('unread_counts', {
                    'total': total,
                    'by_conversation': counts
                }, room=sid)
            
            logger.info(f"Contagem de não lidas enviada para {user_id}")
            
    except Exception as e:
        logger.error(f"Erro ao obter contagem de não lidas: {e}")
        await sio.emit('error', {'message': f'Erro ao obter contagem: {str(e)}'}, room=sid)


# Função para iniciar o servidor
def start_server():
    """Inicia o servidor Socket.IO."""
    host = os.getenv("SOCKETIO_HOST", "0.0.0.0")
    port = int(os.getenv("SOCKETIO_PORT", "8001"))
    
    logger.info(f"Iniciando servidor Socket.IO em {host}:{port}")
    
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level=os.getenv("LOG_LEVEL", "info").lower()
    )


# Ponto de entrada quando executado diretamente
if __name__ == "__main__":
    import uuid  # Importação faltando acima
    start_server()