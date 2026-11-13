"""
API Endpoints for Integra3D.
Receives calculation requests, calls the symbolic engine, and returns academic-grade results.
"""

from typing import List, Optional
from pydantic import BaseModel, Field
from fastapi import APIRouter, HTTPException, UploadFile, File

from app.domain.models import MultivariableIntegral, IntegrationBound, CoordinateSystem
from app.engine.solver import SymPyMultivariableSolver
from app.engine.mesh_generator import Mesh3DGenerator
from app.engine.llm_explainer import LLMExplainer
from app.engine.ocr_engine import MathOcrEngine

router = APIRouter(prefix="/api/v1", tags=["integrals"])


class BoundDTO(BaseModel):
    variable: str = Field(..., example="z")
    lower: str = Field(..., example="0")
    upper: str = Field(..., example="x + y")


class IntegralRequestDTO(BaseModel):
    integrand: str = Field("1", example="x * y")
    bounds: List[BoundDTO] = Field(default_factory=list)
    coordinate_system: Optional[str] = Field("cartesian", example="cartesian")
    problem_mode: Optional[str] = Field("direct", example="direct")
    boundary_curves: Optional[List[str]] = None
    vertices_input: Optional[str] = None
    z_lower_expr: Optional[str] = None
    z_upper_expr: Optional[str] = None
    density_expr: Optional[str] = None
    uv_transform_input: Optional[str] = None
    preferred_order: Optional[str] = None


def _dto_to_domain(dto: IntegralRequestDTO) -> MultivariableIntegral:
    try:
        coord_sys = CoordinateSystem((dto.coordinate_system or "cartesian").lower())
    except ValueError:
        coord_sys = CoordinateSystem.CARTESIAN

    bounds = [
        IntegrationBound(
            variable=b.variable,
            lower=b.lower,
            upper=b.upper
        ) for b in dto.bounds
    ]
    if not bounds and (dto.problem_mode or "direct") != "direct":
        bounds = [
            IntegrationBound(variable="y", lower="0", upper="1"),
            IntegrationBound(variable="x", lower="0", upper="1"),
        ]

    return MultivariableIntegral(
        integrand=dto.integrand,
        bounds=bounds,
        coordinate_system=coord_sys,
        problem_mode=dto.problem_mode or "direct",
        boundary_curves=dto.boundary_curves,
        vertices_input=dto.vertices_input,
        z_lower_expr=dto.z_lower_expr,
        z_upper_expr=dto.z_upper_expr,
        density_expr=dto.density_expr,
        uv_transform_input=dto.uv_transform_input,
        preferred_order=dto.preferred_order,
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
            "id": "image3_double_integral",
            "name": "Integral Doble con Límite Variable",
            "description": "Integral de x*y^2 con x entre 0 y 3y-5, y entre -2 y 1",
            "dimension": 2,
            "integrand": "x * y**2",
            "coordinate_system": "cartesian",
            "bounds": [
                {"variable": "x", "lower": "0", "upper": "3*y - 5"},
                {"variable": "y", "lower": "-2", "upper": "1"}
            ]
        },
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
        },
        {
            "id": "mat212_order_reversal",
            "name": "MAT 212: Inversión de Orden (sin y / y)",
            "description": "Integral doble no elemental en dy: ∫_0^(pi/2) ∫_x^(pi/2) sin(y)/y dy dx",
            "dimension": 2,
            "integrand": "sin(y)/y",
            "coordinate_system": "cartesian",
            "bounds": [
                {"variable": "y", "lower": "x", "upper": "pi/2"},
                {"variable": "x", "lower": "0", "upper": "pi/2"}
            ]
        },
        {
            "id": "mat212_shifted_polar",
            "name": "MAT 212: Circunferencia Desplazada Polar",
            "description": "∫ (x^2+y^2) dA sobre x^2+y^2 <= 2ax => (3/2) pi a^4",
            "dimension": 2,
            "integrand": "r**2",
            "coordinate_system": "polar",
            "bounds": [
                {"variable": "r", "lower": "0", "upper": "2*a*cos(theta)"},
                {"variable": "theta", "lower": "-pi/2", "upper": "pi/2"}
            ]
        },
        {
            "id": "mat212_uv_jacobian",
            "name": "MAT 212: Transformación Jacobiana (u,v)",
            "description": "Área entre xy=1, xy=3, y=x, y=3x",
            "dimension": 2,
            "integrand": "1",
            "coordinate_system": "cartesian",
            "problem_mode": "region_curves",
            "boundary_curves": ["x*y = 1", "x*y = 3", "y = x", "y = 3*x"],
            "bounds": [
                {"variable": "y", "lower": "x", "upper": "3*x"},
                {"variable": "x", "lower": "0", "upper": "1"}
            ]
        },
        {
            "id": "mat212_spherical_ellipsoid",
            "name": "MAT 212: Elipsoide Reescalado Esférico",
            "description": "Volumen de 36z^2 + 9x^2 + 4y^2 <= 144 => 64 pi",
            "dimension": 3,
            "integrand": "1",
            "coordinate_system": "spherical",
            "bounds": [
                {"variable": "rho", "lower": "0", "upper": "24"},
                {"variable": "phi", "lower": "0", "upper": "pi"},
                {"variable": "theta", "lower": "0", "upper": "2*pi"}
            ]
        }
    ]


@router.post("/ocr/transcribe")
async def transcribe_integral(file: UploadFile = File(...)):
    """Transcribes a multivariable integral from an image (camera/gallery)."""
    try:
        image_bytes = await file.read()
        result = MathOcrEngine.transcribe(image_bytes, filename=file.filename or "image.png")
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error en OCR: {str(e)}")


@router.get("/health")
async def health():
    return {"status": "ok", "app": "Integra3D Engine", "sympy_version": "1.14.0"}
