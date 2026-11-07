"""
API Endpoints for Integra3D.
Receives calculation requests, calls the symbolic engine, and returns academic-grade results.
"""

from typing import List, Optional
from pydantic import BaseModel, Field
from fastapi import APIRouter, HTTPException

from app.domain.models import MultivariableIntegral, IntegrationBound, CoordinateSystem
from app.engine.solver import SymPyMultivariableSolver
from app.engine.mesh_generator import Mesh3DGenerator
from app.engine.llm_explainer import LLMExplainer

router = APIRouter(prefix="/api/v1", tags=["integrals"])


class BoundDTO(BaseModel):
    variable: str = Field(..., example="z")
    lower: str = Field(..., example="0")
    upper: str = Field(..., example="x + y")


class IntegralRequestDTO(BaseModel):
    integrand: str = Field(..., example="x * y")
    bounds: List[BoundDTO] = Field(..., min_items=2, max_items=3)
    coordinate_system: Optional[str] = Field("cartesian", example="cartesian")


def _dto_to_domain(dto: IntegralRequestDTO) -> MultivariableIntegral:
    try:
        coord_sys = CoordinateSystem(dto.coordinate_system.lower())
    except ValueError:
        coord_sys = CoordinateSystem.CARTESIAN

    bounds = [
        IntegrationBound(
            variable=b.variable,
            lower=b.lower,
            upper=b.upper
        ) for b in dto.bounds
    ]

    return MultivariableIntegral(
        integrand=dto.integrand,
        bounds=bounds,
        coordinate_system=coord_sys
    )


@router.post("/integral/solve")
async def solve_integral(request: IntegralRequestDTO):
    try:
        integral = _dto_to_domain(request)
        solution = SymPyMultivariableSolver.solve(integral)
        return solution.to_dict()
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/integral/mesh")
async def get_mesh(request: IntegralRequestDTO):
    try:
        integral = _dto_to_domain(request)
        mesh_data = Mesh3DGenerator.generate_mesh(integral)
        return mesh_data
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/integral/explain")
async def get_explanation(request: IntegralRequestDTO):
    try:
        integral = _dto_to_domain(request)
        solution = SymPyMultivariableSolver.solve(integral)
        explanation = LLMExplainer.generate_explanation(integral, solution)
        return explanation
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/integral/presets")
async def get_presets():
    """Returns classic multivariable calculus problems for science fair demonstration."""
    return [
        {
            "id": "paraboloid_cylinder",
            "name": "Volumen bajo Paraboloide sobre Cilindro",
            "description": "Volumen acotado por z = 4 - x^2 - y^2 y el plano z = 0",
            "dimension": 2,
            "integrand": "4 - x**2 - y**2",
            "coordinate_system": "cartesian",
            "bounds": [
                {"variable": "y", "lower": "-sqrt(4 - x**2)", "upper": "sqrt(4 - x**2)"},
                {"variable": "x", "lower": "-2", "upper": "2"}
            ]
        },
        {
            "id": "triple_tetrahedron",
            "name": "Volumen de un Tetraedro Fundamental",
            "description": "Sólido acotado por los planos coordenados y x + y + z = 1",
            "dimension": 3,
            "integrand": "1",
            "coordinate_system": "cartesian",
            "bounds": [
                {"variable": "z", "lower": "0", "upper": "1 - x - y"},
                {"variable": "y", "lower": "0", "upper": "1 - x"},
                {"variable": "x", "lower": "0", "upper": "1"}
            ]
        },
        {
            "id": "gaussian_2d",
            "name": "Integral Doble Gaussiana (Campana de Gauss 2D)",
            "description": "Integral de exp(-x^2 - y^2) en el primer cuadrante",
            "dimension": 2,
            "integrand": "exp(-x**2 - y**2)",
            "coordinate_system": "cartesian",
            "bounds": [
                {"variable": "y", "lower": "0", "upper": "1"},
                {"variable": "x", "lower": "0", "upper": "1"}
            ]
        },
        {
            "id": "cylindrical_cone",
            "name": "Cono Invertido en Coordenadas Cilíndricas",
            "description": "Volumen de un cono z = r hasta altura h=3",
            "dimension": 3,
            "integrand": "1",
            "coordinate_system": "cylindrical",
            "bounds": [
                {"variable": "z", "lower": "r", "upper": "3"},
                {"variable": "r", "lower": "0", "upper": "3"},
                {"variable": "theta", "lower": "0", "upper": "2*pi"}
            ]
        }
    ]


@router.get("/health")
async def health():
    return {"status": "ok", "app": "Integra3D Engine", "sympy_version": "1.14.0"}
