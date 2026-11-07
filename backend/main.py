"""
Main entry point for the Integra3D Python Backend API.
FastAPI app running on Uvicorn.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.endpoints import router as api_router

app = FastAPI(
    title="Integra3D Symbolic & Geometric Engine",
    description="High-precision SymPy solver, step-by-step explainer, and 3D surface generator for Multivariable Calculus.",
    version="1.0.0"
)

# Enable CORS for Flutter mobile/desktop/web client
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
