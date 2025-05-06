import base64
import json
import logging
import os
from typing import Dict, Tuple, Any, Optional

import nacl.public
import nacl.secret
import nacl.utils
from nacl.public import PrivateKey, PublicKey, Box
from nacl.encoding import Base64Encoder

# Configuração de logging
logger = logging.getLogger(__name__)


class ChatEncryption:
    """
    Implementa criptografia ponta-a-ponta para o chat usando NaCl (libsodium).
    Utiliza Curve25519, XSalsa20 e Poly1305 para criptografia autenticada de chave pública.
    """

    @staticmethod
    def generate_keypair() -> Tuple[str, str]:
        """
        Gera um novo par de chaves (privada e pública).
        
        Returns:
            Tupla com (chave privada, chave pública) codificadas em Base64
        """
        # Gerar chave privada
        private_key = PrivateKey.generate()
        
        # Derivar chave pública
        public_key = private_key.public_key
        
        # Codificar em Base64
        private_key_b64 = base64.b64encode(private_key.encode()).decode('utf-8')
        public_key_b64 = base64.b64encode(public_key.encode()).decode('utf-8')
        
        return private_key_b64, public_key_b64

    @staticmethod
    def encrypt_message(
        message: str,
        sender_private_key_b64: str,
        recipient_public_key_b64: str
    ) -> Dict[str, str]:
        """
        Criptografa uma mensagem usando o par de chaves NaCl.
        
        Args:
            message: Mensagem a ser criptografada
            sender_private_key_b64: Chave privada do remetente em Base64
            recipient_public_key_b64: Chave pública do destinatário em Base64
            
        Returns:
            Dicionário com a mensagem criptografada e nonce
        """
        try:
            # Decodificar chaves
            sender_private_key = PrivateKey(
                base64.b64decode(sender_private_key_b64)
            )
            recipient_public_key = PublicKey(
                base64.b64decode(recipient_public_key_b64)
            )
            
            # Criar um Box para criptografia
            box = Box(sender_private_key, recipient_public_key)
            
            # Gerar nonce aleatório
            nonce = nacl.utils.random(Box.NONCE_SIZE)
            
            # Criptografar a mensagem
            encrypted = box.encrypt(message.encode('utf-8'), nonce)
            
            # Extrair a mensagem criptografada (sem o nonce)
            ciphertext = encrypted.ciphertext
            
            return {
                'encrypted': base64.b64encode(ciphertext).decode('utf-8'),
                'nonce': base64.b64encode(nonce).decode('utf-8')
            }
            
        except Exception as e:
            logger.error(f"Erro ao criptografar mensagem: {e}")
            raise

    @staticmethod
    def decrypt_message(
        encrypted_data: Dict[str, str],
        recipient_private_key_b64: str,
        sender_public_key_b64: str
    ) -> str:
        """
        Descriptografa uma mensagem usando o par de chaves NaCl.
        
        Args:
            encrypted_data: Dicionário com a mensagem criptografada e nonce
            recipient_private_key_b64: Chave privada do destinatário em Base64
            sender_public_key_b64: Chave pública do remetente em Base64
            
        Returns:
            Mensagem descriptografada
        """
        try:
            # Decodificar chaves
            recipient_private_key = PrivateKey(
                base64.b64decode(recipient_private_key_b64)
            )
            sender_public_key = PublicKey(
                base64.b64decode(sender_public_key_b64)
            )
            
            # Criar um Box para descriptografia
            box = Box(recipient_private_key, sender_public_key)
            
            # Decodificar dados criptografados
            encrypted = base64.b64decode(encrypted_data['encrypted'])
            nonce = base64.b64decode(encrypted_data['nonce'])
            
            # Descriptografar a mensagem
            decrypted = box.decrypt(encrypted, nonce)
            
            return decrypted.decode('utf-8')
            
        except Exception as e:
            logger.error(f"Erro ao descriptografar mensagem: {e}")
            raise

    @staticmethod
    def encrypt_json(
        data: Dict[str, Any],
        sender_private_key_b64: str,
        recipient_public_key_b64: str
    ) -> str:
        """
        Serializa um dicionário para JSON e depois criptografa.
        
        Args:
            data: Dicionário a ser criptografado
            sender_private_key_b64: Chave privada do remetente em Base64
            recipient_public_key_b64: Chave pública do destinatário em Base64
            
        Returns:
            String com dados JSON criptografados
        """
        # Converter para JSON
        json_data = json.dumps(data)
        
        # Criptografar
        encrypted = ChatEncryption.encrypt_message(
            json_data,
            sender_private_key_b64,
            recipient_public_key_b64
        )
        
        # Retornar como JSON
        return json.dumps(encrypted)

    @staticmethod
    def decrypt_json(
        encrypted_json: str,
        recipient_private_key_b64: str,
        sender_public_key_b64: str
    ) -> Dict[str, Any]:
        """
        Descriptografa e depois desserializa um JSON.
        
        Args:
            encrypted_json: String JSON criptografada
            recipient_private_key_b64: Chave privada do destinatário em Base64
            sender_public_key_b64: Chave pública do remetente em Base64
            
        Returns:
            Dicionário descriptografado
        """
        # Converter de JSON para dicionário
        encrypted_data = json.loads(encrypted_json)
        
        # Descriptografar
        json_data = ChatEncryption.decrypt_message(
            encrypted_data,
            recipient_private_key_b64,
            sender_public_key_b64
        )
        
        # Converter de JSON para dicionário
        return json.loads(json_data)


class KeyManager:
    """
    Gerencia o armazenamento e recuperação de chaves.
    Em produção, seria integrado com um sistema de gestão de chaves seguro.
    """
    
    @staticmethod
    async def get_user_public_key(user_id: str) -> Optional[str]:
        """
        Obtém a chave pública de um usuário.
        
        Args:
            user_id: ID do usuário
            
        Returns:
            Chave pública em Base64 ou None se não existir
        """
        # Em produção, buscaria a chave do banco de dados
        # Aqui é apenas um stub de demonstração
        return f"user_{user_id}_public_key_placeholder"
    
    @staticmethod
    async def get_patient_public_key(patient_id: str) -> Optional[str]:
        """
        Obtém a chave pública de um paciente.
        
        Args:
            patient_id: ID do paciente
            
        Returns:
            Chave pública em Base64 ou None se não existir
        """
        # Em produção, buscaria a chave do banco de dados
        # Aqui é apenas um stub de demonstração
        return f"patient_{patient_id}_public_key_placeholder"
    
    @staticmethod
    async def get_system_keypair() -> Tuple[str, str]:
        """
        Obtém o par de chaves do sistema.
        
        Returns:
            Tupla com (chave privada, chave pública) do sistema
        """
        # Em produção, usaria variáveis de ambiente ou um serviço de gerenciamento de segredos
        # Aqui retorna valores fixos para demonstração
        private_key = os.getenv("SYSTEM_PRIVATE_KEY", "system_private_key_placeholder")
        public_key = os.getenv("SYSTEM_PUBLIC_KEY", "system_public_key_placeholder")
        
        return private_key, public_key
    
    @staticmethod
    async def store_user_public_key(user_id: str, public_key: str) -> None:
        """
        Armazena a chave pública de um usuário.
        
        Args:
            user_id: ID do usuário
            public_key: Chave pública em Base64
        """
        # Em produção, armazenaria a chave no banco de dados
        # Aqui é apenas um stub de demonstração
        logger.info(f"Chave pública do usuário {user_id} armazenada (simulação)")
    
    @staticmethod
    async def store_patient_public_key(patient_id: str, public_key: str) -> None:
        """
        Armazena a chave pública de um paciente.
        
        Args:
            patient_id: ID do paciente
            public_key: Chave pública em Base64
        """
        # Em produção, armazenaria a chave no banco de dados
        # Aqui é apenas um stub de demonstração
        logger.info(f"Chave pública do paciente {patient_id} armazenada (simulação)")


# Exportar funções de conveniência
def generate_keypair() -> Tuple[str, str]:
    """Wrapper para gerar par de chaves."""
    return ChatEncryption.generate_keypair()

def encrypt_message(message: str, sender_private_key: str, recipient_public_key: str) -> Dict[str, str]:
    """Wrapper para criptografar mensagem."""
    return ChatEncryption.encrypt_message(message, sender_private_key, recipient_public_key)

def decrypt_message(encrypted_data: Dict[str, str], recipient_private_key: str, sender_public_key: str) -> str:
    """Wrapper para descriptografar mensagem."""
    return ChatEncryption.decrypt_message(encrypted_data, recipient_private_key, sender_public_key)