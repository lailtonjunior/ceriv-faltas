from datetime import datetime, date
from typing import List, Optional, Dict, Any, Union
from pydantic import BaseModel, EmailStr, Field, validator, UUID4, constr
import re


# ====== Auth Schemas ======
class TokenData(BaseModel):
    sub: str
    exp: datetime
    role: str


class Token(BaseModel):
    access_token: str
    token_type: str
    exp: int  # Expiration timestamp


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class SupabaseAuth(BaseModel):
    token: str
    refresh_token: Optional[str] = None


# ====== Base Schemas ======
class UserBase(BaseModel):
    email: EmailStr
    name: str
    role: str = "staff"
    is_active: bool = True
    avatar_url: Optional[str] = None
    fcm_token: Optional[str] = None


class UserCreate(UserBase):
    password: str

    @validator('password')
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError('A senha deve ter pelo menos 8 caracteres')
        return v


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None
    avatar_url: Optional[str] = None
    fcm_token: Optional[str] = None
    password: Optional[str] = None


class UserOut(UserBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True


class PatientBase(BaseModel):
    name: str
    email: EmailStr
    phone: Optional[str] = None
    birth_date: date
    cpf: str
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zip_code: Optional[str] = None
    is_minor: bool = False
    is_active: bool = True
    fcm_token: Optional[str] = None
    external_id: Optional[str] = None

    @validator('cpf')
    def cpf_validator(cls, v):
        v = re.sub(r'\D', '', v)
        if len(v) != 11:
            raise ValueError('CPF deve conter 11 dígitos')
        return v

    @validator('phone')
    def phone_validator(cls, v):
        if v:
            v = re.sub(r'\D', '', v)
            if len(v) < 10 or len(v) > 11:
                raise ValueError('Telefone deve conter entre 10 e 11 dígitos')
        return v


class PatientCreate(PatientBase):
    pass


class PatientUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    birth_date: Optional[date] = None
    cpf: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    zip_code: Optional[str] = None
    is_minor: Optional[bool] = None
    is_active: Optional[bool] = None
    fcm_token: Optional[str] = None
    profile_completed: Optional[bool] = None
    external_id: Optional[str] = None


class GuardianBase(BaseModel):
    name: str
    email: Optional[EmailStr] = None
    phone: str
    cpf: str
    relationship: str

    @validator('cpf')
    def cpf_validator(cls, v):
        v = re.sub(r'\D', '', v)
        if len(v) != 11:
            raise ValueError('CPF deve conter 11 dígitos')
        return v


class GuardianCreate(GuardianBase):
    pass


class GuardianUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    cpf: Optional[str] = None
    relationship: Optional[str] = None


class GuardianOut(GuardianBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True


class PatientOut(PatientBase):
    id: int
    supabase_id: Optional[UUID4] = None
    profile_completed: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    guardians: List[GuardianOut] = []

    class Config:
        orm_mode = True


class PresenceBase(BaseModel):
    patient_id: int
    date: Optional[datetime] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    method: str = "qr"
    confirmed: bool = True
    notes: Optional[str] = None


class PresenceCreate(PresenceBase):
    pass


class PresenceUpdate(BaseModel):
    date: Optional[datetime] = None
    confirmed: Optional[bool] = None
    confirmed_by: Optional[int] = None
    notes: Optional[str] = None


class PresenceOut(PresenceBase):
    id: int
    confirmed_by: Optional[int] = None
    created_at: datetime

    class Config:
        orm_mode = True


class QRPresenceCreate(BaseModel):
    qr_code: str
    latitude: float
    longitude: float
    patient_id: int


class AbsenceBase(BaseModel):
    patient_id: int
    date: datetime
    is_justified: bool = False
    justification: Optional[str] = None
    document_url: Optional[str] = None
    status: str = "pending"


class AbsenceCreate(AbsenceBase):
    pass


class AbsenceUpdate(BaseModel):
    is_justified: Optional[bool] = None
    justification: Optional[str] = None
    document_url: Optional[str] = None
    status: Optional[str] = None
    review_notes: Optional[str] = None


class AbsenceOut(AbsenceBase):
    id: int
    reviewed_by: Optional[int] = None
    review_date: Optional[datetime] = None
    review_notes: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True


class TermVersionBase(BaseModel):
    version: str
    title: str
    content: str
    is_active: bool = True


class TermVersionCreate(TermVersionBase):
    author_id: int


class TermVersionUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    is_active: Optional[bool] = None


class TermVersionOut(TermVersionBase):
    id: int
    author_id: int
    created_at: datetime

    class Config:
        orm_mode = True


class TermAcceptanceBase(BaseModel):
    patient_id: int
    term_version_id: int
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    signature_url: Optional[str] = None
    signature_text: Optional[str] = None
    guardian_signature_url: Optional[str] = None
    guardian_signature_text: Optional[str] = None


class TermAcceptanceCreate(TermAcceptanceBase):
    pass


class TermAcceptanceOut(TermAcceptanceBase):
    id: int
    accepted_at: datetime
    pdf_url: Optional[str] = None

    class Config:
        orm_mode = True


class BadgeBase(BaseModel):
    name: str
    description: Optional[str] = None
    icon_url: Optional[str] = None
    points: int = 0
    category: str
    requirements: Optional[Dict[str, Any]] = None
    is_active: bool = True


class BadgeCreate(BadgeBase):
    pass


class BadgeUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    icon_url: Optional[str] = None
    points: Optional[int] = None
    category: Optional[str] = None
    requirements: Optional[Dict[str, Any]] = None
    is_active: Optional[bool] = None


class BadgeOut(BadgeBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True


class PatientBadgeBase(BaseModel):
    patient_id: int
    badge_id: int


class PatientBadgeCreate(PatientBadgeBase):
    pass


class PatientBadgeOut(PatientBadgeBase):
    id: int
    awarded_at: datetime
    notified: bool
    badge: BadgeOut

    class Config:
        orm_mode = True


class MessageBase(BaseModel):
    conversation_id: UUID4
    patient_id: int
    sender_type: str
    content: str
    encrypted: bool = True
    attachment_url: Optional[str] = None
    attachment_type: Optional[str] = None


class MessageCreate(MessageBase):
    user_id: Optional[int] = None


class MessageUpdate(BaseModel):
    read: Optional[bool] = None
    read_at: Optional[datetime] = None


class MessageOut(MessageBase):
    id: int
    user_id: Optional[int] = None
    read: bool
    read_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        orm_mode = True


class NotificationBase(BaseModel):
    title: str
    message: str
    type: str
    data: Optional[Dict[str, Any]] = None


class NotificationCreate(NotificationBase):
    patient_id: Optional[int] = None
    user_id: Optional[int] = None


class NotificationUpdate(BaseModel):
    read: Optional[bool] = None
    read_at: Optional[datetime] = None


class NotificationOut(NotificationBase):
    id: int
    patient_id: Optional[int] = None
    user_id: Optional[int] = None
    read: bool
    read_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        orm_mode = True


class AbsenceRuleBase(BaseModel):
    name: str
    description: Optional[str] = None
    consecutive_limit: Optional[int] = None
    period_limit: Optional[int] = None
    period_days: Optional[int] = None
    is_active: bool = True


class AbsenceRuleCreate(AbsenceRuleBase):
    pass


class AbsenceRuleUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    consecutive_limit: Optional[int] = None
    period_limit: Optional[int] = None
    period_days: Optional[int] = None
    is_active: Optional[bool] = None


class AbsenceRuleOut(AbsenceRuleBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True