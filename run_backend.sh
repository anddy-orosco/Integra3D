#!/bin/bash
# Script de inicio rápido del Backend de Integra3D (Apple Silicon M2)
echo "=========================================================="
echo "    Iniciando Motor Matemático SymPy & Mesh de Integra3D   "
echo "=========================================================="
export PYTHONPATH=backend
python3 -m uvicorn main:app --app-dir backend --host 0.0.0.0 --port 8000 --reload
