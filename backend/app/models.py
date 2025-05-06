import uuid
from datetime import datetime
from typing import Optional, List
from sqlalchemy.ext.declarative import declarative_base

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Table, Text, Boolean, Float, func

from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base

Base = declarative_base()

# Definir a tabela de associação corretamente
patient_guardian = Table(
    'patient_guardian',
    Base.metadata,
    Column('patient_id', Integer, ForeignKey('patients.id')),
    Column('guardian_id', Integer, ForeignKey('guardians.id'))
)

# Tabela de associação entre pacientes e responsáveis
patient_guardian = Table(
    "patient_guardian",
    Base.metadata,
    Column("patient_id", Integer, ForeignKey("patients.id"), primary_key=True),
    Column("guardian_id", Integer, ForeignKey("guardians.id"), primary_key=True),
)

class User(Base):
    """Modelo para usuários do sistema (profissionais)"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    name = Column(String(255), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False, default="staff")  # staff, admin
    is_active = Column(Boolean, default=True)
    avatar_url = Column(String(255), nullable=True)
    fcm_token = Column(String(255), nullable=True)  # Token para notificações push
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relacionamentos
    messages = relationship("Message", back_populates="user", foreign_keys="Message.user_id")
    term_versions = relationship("TermVersion", back_populates="author")

    def __repr__(self):
        return f"User(id={self.id}, email={self.email}, role={self.role})"


class Patient(Base):
    """Modelo para pacientes"""
    __tablename__ = "patients"

    id = Column(Integer, primary_key=True, index=True)
    external_id = Column(String(100), nullable=True, index=True)  # ID no sistema de prontuário
    supabase_id = Column(UUID(as_uuid=True), nullable=True, index=True)  # ID no Supabase Auth
    name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    phone = Column(String(20), nullable=True)
    birth_date = Column(DateTime(timezone=True), nullable=False)
    cpf = Column(String(14), unique=True, index=True, nullable=False)
    address = Column(String(255), nullable=True)
    city = Column(String(100), nullable=True)
    state = Column(String(2), nullable=True)
    zip_code = Column(String(10), nullable=True)
    is_minor = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    fcm_token = Column(String(255), nullable=True)  # Token para notificações push
    profile_completed = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relacionamentos
    guardians = relationship("Guardian", secondary=patient_guardian, back_populates="patients")
    presences = relationship("Presence", back_populates="patient")
    absences = relationship("Absence", back_populates="patient")
    term_acceptances = relationship("TermAcceptance", back_populates="patient")
    badges = relationship("PatientBadge", back_populates="patient")
    messages = relationship("Message", back_populates="patient", foreign_keys="Message.patient_id")

    def __repr__(self):
        return f"Patient(id={self.id}, name={self.name}, email={self.email})"


class Guardian(Base):
    """Modelo para responsáveis de pacientes menores de idade"""
    __tablename__ = "guardians"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    email = Column(String(255), nullable=True)
    phone = Column(String(20), nullable=False)
    cpf = Column(String(14), unique=True, index=True, nullable=False)
    relationship = Column(String(50), nullable=False)  # pai, mãe, tutor legal, etc.
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relacionamentos
    patients = relationship("Patient", secondary=patient_guardian, back_populates="guardians")

    def __repr__(self):
        return f"Guardian(id={self.id}, name={self.name}, relationship={self.relationship})"


class Presence(Base):
    """Modelo para registro de presenças"""
    __tablename__ = "presences"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.id"), nullable=False)
    date = Column(DateTime(timezone=True), server_default=func.now())
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    method = Column(String(20), nullable=False, default="qr")  # qr, manual, beacon
    confirmed = Column(Boolean, default=True)
    confirmed_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relacionamentos
    patient = relationship("Patient", back_populates="presences")

    def __repr__(self):
        return f"Presence(id={self.id}, patient_id={self.patient_id}, date={self.date})"


class Absence(Base):
    """Modelo para faltas justificadas e não justificadas"""
    __tablename__ = "absences"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.id"), nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    is_justified = Column(Boolean, default=False)
    justification = Column(Text, nullable=True)
    document_url = Column(String(255), nullable=True)  # URL para documento comprobatório
    status = Column(String(20), default="pending")  # pending, approved, rejected
    reviewed_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    review_date = Column(DateTime(timezone=True), nullable=True)
    review_notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relacionamentos
    patient = relationship("Patient", back_populates="absences")

    def __repr__(self):
        return f"Absence(id={self.id}, patient_id={self.patient_id}, date={self.date})"


class AbsenceRule(Base):
    """Regras para identificação de faltas excessivas"""
    __tablename__ = "absence_rules"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    consecutive_limit = Column(Integer, nullable=True)  # Limite de faltas consecutivas
    period_limit = Column(Integer, nullable=True)  # Limite de faltas em um período
    period_days = Column(Integer, nullable=True)  # Período em dias
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"AbsenceRule(id={self.id}, name={self.name})"


class Badge(Base):
    """Modelo para badges de gamificação"""
    __tablename__ = "badges"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    description = Column(Text, nullable=True)
    icon_url = Column(String(255), nullable=True)
    points = Column(Integer, default=0)
    category = Column(String(50), nullable=False)  # assiduidade, progresso, engajamento
    requirements = Column(JSONB, nullable=True)  # Critérios em JSON para conquistar o badge
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relacionamentos
    patient_badges = relationship("PatientBadge", back_populates="badge")

    def __repr__(self):
        return f"Badge(id={self.id}, name={self.name}, points={self.points})"


class PatientBadge(Base):
    """Associação entre pacientes e badges conquistados"""
    __tablename__ = "patient_badges"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.id"), nullable=False)
    badge_id = Column(Integer, ForeignKey("badges.id"), nullable=False)
    awarded_at = Column(DateTime(timezone=True), server_default=func.now())
    notified = Column(Boolean, default=False)

    # Relacionamentos
    patient = relationship("Patient", back_populates="badges")
    badge = relationship("Badge", back_populates="patient_badges")

    # Restrição única para evitar duplicatas
    __table_args__ = (UniqueConstraint('patient_id', 'badge_id', name='uix_patient_badge'),)

    def __repr__(self):
        return f"PatientBadge(patient_id={self.patient_id}, badge_id={self.badge_id})"


class TermVersion(Base):
    """Modelo para versões dos termos de adesão"""
    __tablename__ = "term_versions"

    id = Column(Integer, primary_key=True, index=True)
    version = Column(String(20), nullable=False, unique=True)
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    is_active = Column(Boolean, default=True)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relacionamentos
    author = relationship("User", back_populates="term_versions")
    acceptances = relationship("TermAcceptance", back_populates="term_version")

    def __repr__(self):
        return f"TermVersion(id={self.id}, version={self.version})"


class TermAcceptance(Base):
    """Modelo para aceitação dos termos pelos pacientes"""
    __tablename__ = "term_acceptances"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.id"), nullable=False)
    term_version_id = Column(Integer, ForeignKey("term_versions.id"), nullable=False)
    accepted_at = Column(DateTime(timezone=True), server_default=func.now())
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(255), nullable=True)
    signature_url = Column(String(255), nullable=True)  # URL para a assinatura manuscrita
    signature_text = Column(String(255), nullable=True)  # Assinatura por extenso
    guardian_signature_url = Column(String(255), nullable=True)
    guardian_signature_text = Column(String(255), nullable=True)
    pdf_url = Column(String(255), nullable=True)  # URL para o PDF gerado

    # Relacionamentos
    patient = relationship("Patient", back_populates="term_acceptances")
    term_version = relationship("TermVersion", back_populates="acceptances")

    def __repr__(self):
        return f"TermAcceptance(id={self.id}, patient_id={self.patient_id})"


class Message(Base):
    """Modelo para mensagens do chat"""
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    conversation_id = Column(UUID(as_uuid=True), nullable=False, index=True, default=uuid.uuid4)
    patient_id = Column(Integer, ForeignKey("patients.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    sender_type = Column(String(10), nullable=False)  # patient, staff
    content = Column(Text, nullable=False)
    encrypted = Column(Boolean, default=True)
    read = Column(Boolean, default=False)
    read_at = Column(DateTime(timezone=True), nullable=True)
    attachment_url = Column(String(255), nullable=True)
    attachment_type = Column(String(50), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relacionamentos
    patient = relationship("Patient", back_populates="messages", foreign_keys=[patient_id])
    user = relationship("User", back_populates="messages", foreign_keys=[user_id])

    def __repr__(self):
        return f"Message(id={self.id}, conversation_id={self.conversation_id}, sender_type={self.sender_type})"


class Notification(Base):
    """Modelo para notificações"""
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.id"), nullable=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    type = Column(String(50), nullable=False)  # appointment, absence, badge, system
    read = Column(Boolean, default=False)
    read_at = Column(DateTime(timezone=True), nullable=True)
    data = Column(JSONB, nullable=True)  # Dados adicionais em JSON
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    def __repr__(self):
        return f"Notification(id={self.id}, type={self.type}, title={self.title})"