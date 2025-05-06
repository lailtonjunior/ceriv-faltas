import logging
import os
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager

from app.database import engine, get_db
from app.routers import auth, patients, presence, chat, gamification, terms
from app.services import security

# Configurar logging
logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO")),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Inicialização do aplicativo
    logger.info("Inicializando o aplicativo CER IV")
    yield
    # Limpeza ao desligar
    logger.info("Desligando o aplicativo CER IV")

# Criar instância do FastAPI
app = FastAPI(
    title="CER IV API",
    description="API para o aplicativo do Centro Especializado em Reabilitação",
    version="1.0.0",
    lifespan=lifespan,
)

# Configurar CORS
origins = os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Middleware para tratar exceções globalmente
@app.middleware("http")
async def errors_handling(request: Request, call_next):
    try:
        return await call_next(request)
    except Exception as exc:
        logger.error(f"Erro não tratado: {exc}")
        return JSONResponse(
            status_code=500,
            content={"detail": "Ocorreu um erro interno no servidor."},
        )

# Incluir routers
app.include_router(auth.router, prefix="/api", tags=["Autenticação"])
app.include_router(patients.router, prefix="/api", tags=["Pacientes"])
app.include_router(presence.router, prefix="/api", tags=["Presenças"])
app.include_router(chat.router, prefix="/api", tags=["Chat"])
app.include_router(gamification.router, prefix="/api", tags=["Gamificação"])
app.include_router(terms.router, prefix="/api", tags=["Termos"])

# Rota para verificar saúde da API
@app.get("/health", tags=["Saúde"])
async def health_check():
    return {"status": "ok", "message": "API CER IV em funcionamento"}

# Rota protegida para testar autenticação
@app.get("/api/protected", tags=["Teste"])
async def protected_route(current_user=Depends(security.get_current_user)):
    return {"message": f"Olá, {current_user.name}!", "user_id": current_user.id}

# Rota para integração com prontuário eletrônico
@app.get("/api/cer-integration/evolutions/{patient_id}", tags=["Integração"])
async def get_patient_evolutions(
    patient_id: int, current_user=Depends(security.get_current_user)
):
    # Stub: Aqui seria implementada a integração real com o prontuário
    return {
        "patient_id": patient_id,
        "evolutions": [
            {
                "id": 1,
                "date": "2023-11-01",
                "professional": "Dr. Maria Silva",
                "description": "Paciente apresentou melhora significativa na movimentação.",
            },
            {
                "id": 2,
                "date": "2023-11-15",
                "professional": "Dr. José Santos",
                "description": "Continuidade no tratamento com foco em exercícios de fortalecimento.",
            },
        ],
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)