"""
Pedagogical LLM Explainer for Integra3D.
Implements the hybrid architecture: SymPy (Engine) + AI (Pedagogy).
Generates academic explanations, geometric intuition, and textbook-style step-by-step breakdowns.
"""

import os
import json
import urllib.request
import urllib.error
from typing import Dict, Any, List, Optional
from app.domain.models import MultivariableIntegral, CoordinateSystem
from app.engine.solver import IntegralSolution, SolverStep


class LLMExplainer:
    """
    Synthesizes SymPy mathematical rigor and AI pedagogical clarity
    into an academic textbook experience for multivariable calculus students.
    """

    SYSTEM_PROMPT = """Eres un profesor universitario titular de Cálculo Multivariable y Álgebra Simbólica.
Tu tarea es resolver y redactar el desarrollo paso a paso y la explicación pedagógica con máxima elegancia didáctica, rigor y claridad (estilo libro de texto de James Stewart / Larson / Thomas).
Se te proporcionarán los puntos de control exactos ya calculados y verificados por el motor matemático simbólico (SymPy).

METODOLOGÍA OBLIGATORIA EN DOS FASES:
FASE 1 (Resolución Interna Previa y Conteo de Pasos):
- Resuelve primero todo el ejercicio internamente de principio a fin hasta obtener el resultado exacto.
- Determina cuántos pasos matemáticos lógicos y necesarios te tomó resolverlo.
- ¡NO HAY UNA CANTIDAD DE PASOS DEFINIDA! La cantidad de paquetes de pasos en "steps" es 100% DINÁMICA y VARIABLE según la dificultad:
  * Integrales directas: 3 a 5 pasos.
  * Expansión de polinomios, productos o fracciones: 5 a 7 pasos.
  * Cambio de orden de integración (Fubini inverso), u-sustitución o partes: 7, 8, 9, 10 o más pasos.
  * Recintos circulares con Jacobiano r: 6 a 9 pasos.
- NUNCA limites ni fuerces la resolución a un número fijo (como 3 o 6 pasos).

FASE 2 (Empaquetado de Pasos para la Aplicación):
- Empaqueta CADA PASO individualmente en un objeto dentro del array "steps".
- La aplicación móvil contará los pasos y creará exactamente UN CUADRO didáctico por cada paquete.
- Cada paquete de paso debe incluir:
  {
    "step_number": 1,
    "variable": "y",
    "step_title": "Paso 1: [Título claro de la acción]",
    "step_integral_latex": "fórmula o integral planteada en este paso en LaTeX puro",
    "constant_treatment_text": "qué estás haciendo en este paso (método, tratamiento de variables, etc.)",
    "antiderivative_work_latex": "fórmula del desarrollo o antiderivada calculada",
    "limits_evaluation_text": "texto de evaluación en límites o sustitución (si aplica)",
    "evaluated_latex": "fórmula de la evaluación F(b) - F(a) o resultado de sustitución",
    "simplified_result_latex": "expresión resultante tras este paso (que pasa al siguiente paso)",
    "explanation": "explicación pedagógica clara y concisa",
    "applied_method": "nombre del método o teorema aplicado"
  }

REGLAS OBLIGATORIAS:
1. Responde ÚNICAMENTE con un objeto JSON válido (sin bloques ```json, sin encabezados ni texto conversacional).
2. Usa notación LaTeX pura para todas las fórmulas matemáticas (escapa las barras invertidas dentro de cadenas JSON usando \\\\).
3. Utiliza EXACTAMENTE los puntos de control matemáticos proporcionados (antiderivadas, límites y resultado final exacto). NUNCA inventes números ni signos.
4. NUNCA uses letras abstractas ni funciones ficticias como A(x) o B(y). Escribe siempre expresiones explícitas completas.

APARTADO OBLIGATORIO DE FORMULARIO Y MÉTODOS ("formulas_and_methods"):
Incluye OBLIGATORIAMENTE un array con los teoremas, reglas y fórmulas generales empleadas en el ejercicio:
[
  {
    "name": "Nombre canónico del teorema o regla (ej. Teorema de Fubini)",
    "formula_latex": "Fórmula teórica general en LaTeX puro (ej. \\\\iint_R f dA = \\\\int_{a}^{b} \\\\int_{g_1}^{g_2} f dy dx)",
    "description": "Explicación conceptual y teórica del método o teorema",
    "application": "Cómo y en qué paso específico se aplicó en este ejercicio"
  }
]

ESTRUCTURA GENERAL DE LA RESPUESTA JSON:
{
  "integral_latex": "string con la integral completa planteada en LaTeX",
  "region_definition": "string didáctico definiendo la región de integración",
  "steps": [ ... ],
  "formulas_and_methods": [ ... ],
  "sections": [
    { "title": "1. Interpretación Geométrica y Planteamiento", "content": "..." },
    { "title": "2. Orden de Integración y Teorema de Fubini", "content": "..." },
    { "title": "3. Conclusión y Verificación del Resultado", "content": "..." }
  ],
  "exact_result_latex": "resultado exacto en LaTeX",
  "decimal_result": 8.0,
  "domain_analysis": {
    "region_type": "Type I | Type II | Polar | UV_Jacobian | Cylindrical | Spherical",
    "intersection_points": [{"x": "0", "y": "0"}],
    "deduced_limits_latex": "explicación en KaTeX de cómo se despejaron las cotas",
    "jacobian_latex": "desarrollo del determinante Jacobiano si aplica"
  }
}
"""

    @classmethod
    def generate_explanation(
        cls,
        integral: MultivariableIntegral,
        solution: IntegralSolution,
        api_key: str = ""
    ) -> Dict[str, Any]:
        """
        Generates structured didactic explanation.
        Tries Gemini Flash or OpenRouter using verified checkpoints,
        and falls back seamlessly to the algorithmic textbook template if offline or without keys.
        """
        # 1. Prepare verified checkpoints from SymPy
        checkpoints = cls._build_checkpoints(integral, solution)

        # 2. Determine available key
        effective_key = api_key.strip() or os.environ.get("GEMINI_API_KEY", "").strip() or os.environ.get("OPENROUTER_API_KEY", "").strip()

        # 3. Attempt LLM generation if key exists
        if effective_key:
            try:
                ai_result = cls._call_llm_service(checkpoints, effective_key)
                if ai_result and "steps" in ai_result and len(ai_result["steps"]) > 0:
                    # Enforce exact checkpoints to prevent any arithmetic hallucinations
                    ai_result["exact_result_latex"] = solution.exact_latex
                    ai_result["decimal_result"] = solution.approx_numeric
                    if not ai_result.get("region_definition"):
                        ai_result["region_definition"] = solution.region_definition or checkpoints.get("region_definition", "")
                    if not ai_result.get("domain_analysis") and getattr(solution, "domain_analysis", None):
                        ai_result["domain_analysis"] = solution.domain_analysis
                    return ai_result
            except Exception:
                # Logging can be added; gracefully fallback to algorithmic generator
                pass

        # 4. Resilient algorithmic textbook generator
        return cls._generate_algorithmic_explanation(integral, solution, checkpoints)

    @classmethod
    def _build_checkpoints(
        cls,
        integral: MultivariableIntegral,
        solution: IntegralSolution
    ) -> Dict[str, Any]:
        steps_data = []
        for s in solution.steps:
            steps_data.append({
                "step_number": s.step_number,
                "variable": s.variable,
                "lower_bound_latex": s.lower_bound_latex,
                "upper_bound_latex": s.upper_bound_latex,
                "current_integrand_latex": s.current_integrand_latex,
                "antiderivative_latex": s.antiderivative_latex,
                "evaluated_latex": s.evaluated_latex,
                "simplified_result_latex": s.simplified_result_latex,
                "step_title": s.step_title,
                "step_integral_latex": s.step_integral_latex,
                "constant_treatment_text": s.constant_treatment_text,
                "antiderivative_work_latex": s.antiderivative_work_latex,
                "limits_evaluation_text": s.limits_evaluation_text,
                "applied_method": s.applied_method,
                "is_limit_inverted": s.is_limit_inverted,
            })

        return {
            "integral_latex": solution.original_integral_latex,
            "dimension": integral.dimension,
            "coordinate_system": integral.coordinate_system.value,
            "region_definition": solution.region_definition or "",
            "exact_result_latex": solution.exact_latex,
            "decimal_result": solution.approx_numeric,
            "steps": steps_data,
            **({"domain_analysis": solution.domain_analysis} if getattr(solution, "domain_analysis", None) else {}),
        }

    @classmethod
    def _call_llm_service(cls, checkpoints: Dict[str, Any], api_key: str) -> Optional[Dict[str, Any]]:
        user_message = f"Genera la explicación y pasos pedagógicos para esta integral:\n{json.dumps(checkpoints, ensure_ascii=False)}"

        if api_key.startswith("sk-or-"):
            # OpenRouter endpoint
            url = "https://openrouter.ai/api/v1/chat/completions"
            payload = {
                "model": "google/gemini-2.0-flash-exp:free",
                "messages": [
                    {"role": "system", "content": cls.SYSTEM_PROMPT},
                    {"role": "user", "content": user_message}
                ],
                "temperature": 0.1,
                "response_format": {"type": "json_object"}
            }
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
                "HTTP-Referer": "https://integra3d.app",
                "X-Title": "Integra3D"
            }
            req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
            with urllib.request.urlopen(req, timeout=12) as response:
                res_data = json.loads(response.read().decode("utf-8"))
                content = res_data["choices"][0]["message"]["content"]
                return json.loads(content)
        else:
            # Gemini Flash API endpoint
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={api_key}"
            payload = {
                "system_instruction": {
                    "parts": [{"text": cls.SYSTEM_PROMPT}]
                },
                "contents": [
                    {"parts": [{"text": user_message}]}
                ],
                "generationConfig": {
                    "temperature": 0.1,
                    "response_mime_type": "application/json"
                }
            }
            headers = {"Content-Type": "application/json"}
            req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
            with urllib.request.urlopen(req, timeout=12) as response:
                res_data = json.loads(response.read().decode("utf-8"))
                text = res_data["candidates"][0]["content"]["parts"][0]["text"]
                return json.loads(text)

    @classmethod
    def _generate_algorithmic_explanation(
        cls,
        integral: MultivariableIntegral,
        solution: IntegralSolution,
        checkpoints: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Generates a rich textbook pedagogical breakdown algorithmically from SymPy steps.
        Guarantees 100% mathematical accuracy and zero network dependency.
        """
        dimension_str = "Doble (2D)" if integral.dimension == 2 else "Triple (3D)"
        coords_str = integral.coordinate_system.value.capitalize()

        # Geometric intuition
        if integral.dimension == 2:
            if integral.integrand_str.strip() == "1":
                geometric_meaning = "El cálculo representa el Área geométrica de la región plana acotada en el plano."
            else:
                geometric_meaning = f"El cálculo representa el Volumen neto bajo la superficie $z = {integral.integrand_str}$ sobre la región acotada."
        else:
            if integral.integrand_str.strip() == "1":
                geometric_meaning = "El cálculo representa el Volumen del sólido tridimensional acotado por las superficies límite."
            else:
                geometric_meaning = "El cálculo representa la Masa total del cuerpo (asumiendo que el integrando modela una función de densidad volumétrica $\\rho(x,y,z)$)."

        jacobian_note = ""
        if integral.coordinate_system == CoordinateSystem.CYLINDRICAL:
            jacobian_note = " Se aplicó el factor Jacobiano $J = r$ del elemento diferencial de volumen: $dV = r \\, dz \\, dr \\, d\\theta$."
        elif integral.coordinate_system == CoordinateSystem.SPHERICAL:
            jacobian_note = " Se aplicó el factor Jacobiano $J = \\rho^2 \\sin(\\phi)$ del elemento diferencial: $dV = \\rho^2 \\sin(\\phi) \\, d\\rho \\, d\\phi \\, d\\theta$."

        sections = [
            {
                "title": "1. Interpretación Geométrica y Planteamiento",
                "content": f"Nos enfrentamos a una Integral {dimension_str} en sistema de coordenadas {coords_str}. {geometric_meaning}{jacobian_note}"
            },
            {
                "title": "2. Orden de Integración y Teorema de Fubini",
                "content": (
                    f"El orden de integración seleccionado es {' -> '.join(integral.variables)}. "
                    "Por el Teorema de Fubini, las capas interiores se resuelven tratando las variables exteriores "
                    "estrictamente como parámetros constantes antes de evaluar los límites en cada paso."
                )
            },
            {
                "title": "3. Conclusión y Verificación del Resultado",
                "content": (
                    f"El valor exacto calculado simbólicamente es $\\mathbf{{{solution.exact_latex}}}$, "
                    + (f"equivalente a aproximadamente **{solution.approx_numeric}** unidades." if solution.approx_numeric is not None else "")
                )
            }
        ]

        steps = []
        for s in solution.steps:
            steps.append({
                "step_number": s.step_number,
                "variable": s.variable,
                "step_title": s.step_title or f"Paso {s.step_number}: Integración con respecto a {s.variable}",
                "step_integral_latex": s.step_integral_latex or f"\\int_{{{s.lower_bound_latex}}}^{{{s.upper_bound_latex}}} {s.current_integrand_latex} \\, d{s.variable}",
                "constant_treatment_text": s.constant_treatment_text or f"Integramos respecto a {s.variable}:",
                "antiderivative_work_latex": s.antiderivative_work_latex or f"\\int {s.current_integrand_latex} \\, d{s.variable} = {s.antiderivative_latex}",
                "limits_evaluation_text": s.limits_evaluation_text or f"Ahora evaluamos en los límites {s.variable} = {s.lower_bound_latex} y {s.variable} = {s.upper_bound_latex}:",
                "evaluated_latex": s.evaluated_latex,
                "simplified_result_latex": s.simplified_result_latex,
                "explanation": s.explanation,
                "applied_method": s.applied_method or "Teorema Fundamental del Cálculo & Fubini",
                "is_limit_inverted": s.is_limit_inverted,
            })

        result: Dict[str, Any] = {
            "title": f"Análisis Pedagógico de la Integral {dimension_str}",
            "integral_latex": solution.original_integral_latex,
            "region_definition": solution.region_definition or checkpoints.get("region_definition", ""),
            "steps": steps,
            "formulas_and_methods": [f.to_dict() for f in getattr(solution, "formulas_and_methods", [])],
            "sections": sections,
            "exact_result_latex": solution.exact_latex,
            "decimal_result": solution.approx_numeric,
            "solution_latex": solution.exact_latex,
            "approx_numeric": solution.approx_numeric,
        }
        if getattr(solution, "domain_analysis", None):
            result["domain_analysis"] = solution.domain_analysis
        if getattr(solution, "application_summary", None):
            result["application_summary"] = solution.application_summary
        return result
