"""
SymPy Multivariable Solver Engine for Integra3D.
Performs step-by-step symbolic integration, limit evaluation, and error diagnosis.
"""

import time
from typing import List, Dict, Any, Optional
import sympy as sp
from app.domain.models import MultivariableIntegral, IntegrationBound, CoordinateSystem
from app.engine.mat212_helpers import (
    build_domain_analysis,
    has_non_elementary,
    solve_mat212_mode,
    try_general_order_reversal,
)


class SolverStep:
    """Represents a single step in the algebraic integration chain."""
    def __init__(
        self,
        step_number: int,
        variable: str,
        lower_bound_latex: str,
        upper_bound_latex: str,
        current_integrand_latex: str,
        antiderivative_latex: str,
        evaluated_latex: str,
        simplified_result_latex: str,
        explanation: str,
        applied_method: Optional[str] = None,
        is_limit_inverted: bool = False,
        step_title: Optional[str] = None,
        step_integral_latex: Optional[str] = None,
        constant_treatment_text: Optional[str] = None,
        antiderivative_work_latex: Optional[str] = None,
        limits_evaluation_text: Optional[str] = None
    ):
        self.step_number = step_number
        self.variable = variable
        self.lower_bound_latex = lower_bound_latex
        self.upper_bound_latex = upper_bound_latex
        self.current_integrand_latex = current_integrand_latex
        self.antiderivative_latex = antiderivative_latex
        self.evaluated_latex = evaluated_latex
        self.simplified_result_latex = simplified_result_latex
        self.explanation = explanation
        self.applied_method = applied_method
        self.is_limit_inverted = is_limit_inverted
        self.step_title = step_title
        self.step_integral_latex = step_integral_latex
        self.constant_treatment_text = constant_treatment_text
        self.antiderivative_work_latex = antiderivative_work_latex
        self.limits_evaluation_text = limits_evaluation_text

    def to_dict(self) -> Dict[str, Any]:
        return {
            "step_number": self.step_number,
            "variable": self.variable,
            "lower_bound_latex": self.lower_bound_latex,
            "upper_bound_latex": self.upper_bound_latex,
            "current_integrand_latex": self.current_integrand_latex,
            "antiderivative_latex": self.antiderivative_latex,
            "evaluated_latex": self.evaluated_latex,
            "simplified_result_latex": self.simplified_result_latex,
            "explanation": self.explanation,
            "applied_method": self.applied_method,
            "is_limit_inverted": self.is_limit_inverted,
            "step_title": self.step_title,
            "step_integral_latex": self.step_integral_latex,
            "constant_treatment_text": self.constant_treatment_text,
            "antiderivative_work_latex": self.antiderivative_work_latex,
            "limits_evaluation_text": self.limits_evaluation_text
        }


class FormulaMethodCard:
    """Card representing a theoretical formula, rule or theorem applied in the solution."""
    def __init__(self, name: str, formula_latex: str, description: str, application: Optional[str] = None):
        self.name = name
        self.formula_latex = formula_latex
        self.description = description
        self.application = application

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "formula_latex": self.formula_latex,
            "description": self.description,
            "application": self.application
        }


class IntegralSolution:
    """Encapsulates the final symbolic and numerical result along with pedagogical steps."""
    def __init__(
        self,
        is_success: bool,
        exact_latex: str,
        approx_numeric: Optional[float] = None,
        steps: Optional[List[SolverStep]] = None,
        original_integral_latex: str = "",
        error_message: Optional[str] = None,
        execution_time_ms: float = 0.0,
        region_definition: Optional[str] = None,
        sections: Optional[List[Dict[str, Any]]] = None,
        formulas_and_methods: Optional[List[FormulaMethodCard]] = None,
        domain_analysis: Optional[Dict[str, Any]] = None,
        application_summary: Optional[Dict[str, Any]] = None,
    ):
        self.is_success = is_success
        self.exact_latex = exact_latex
        self.approx_numeric = approx_numeric
        self.steps = steps or []
        self.original_integral_latex = original_integral_latex
        self.error_message = error_message
        self.execution_time_ms = execution_time_ms
        self.region_definition = region_definition
        self.sections = sections or []
        self.formulas_and_methods = formulas_and_methods or []
        self.domain_analysis = domain_analysis
        self.application_summary = application_summary

    def to_dict(self) -> Dict[str, Any]:
        payload: Dict[str, Any] = {
            "is_success": self.is_success,
            "exact_latex": self.exact_latex,
            "approx_numeric": self.approx_numeric,
            "steps": [s.to_dict() for s in self.steps],
            "original_integral_latex": self.original_integral_latex,
            "error_message": self.error_message,
            "execution_time_ms": self.execution_time_ms,
            "region_definition": self.region_definition,
            "sections": self.sections,
            "formulas_and_methods": [f.to_dict() for f in self.formulas_and_methods]
        }
        if self.domain_analysis is not None:
            payload["domain_analysis"] = self.domain_analysis
        if self.application_summary is not None:
            payload["application_summary"] = self.application_summary
        return payload


class SymPyMultivariableSolver:
    """
    High-rigor engine utilizing SymPy for iterated symbolic calculus.
    """

    @staticmethod
    def solve(integral: MultivariableIntegral) -> IntegralSolution:
        start_time = time.perf_counter()
        if getattr(integral, "problem_mode", "direct") != "direct":
            mode_sol = solve_mat212_mode(integral, SymPyMultivariableSolver, SolverStep, IntegralSolution, start_time)
            if mode_sol is not None:
                return mode_sol

        original_latex = integral.to_latex()
        
        try:
            current_expr = integral.effective_integrand()
            steps: List[SolverStep] = []
            
            # Integrate iteratively from innermost variable (index 0) to outermost
            for i, bound in enumerate(integral.bounds, start=1):
                var = bound.var_sym
                lower = bound.lower_expr
                upper = bound.upper_expr
                
                integrand_before_step = current_expr
                integrand_latex = sp.latex(integrand_before_step)
                
                # 1. Antiderivative with respect to current variable
                try:
                    antiderivative = sp.integrate(current_expr, var)
                except Exception as e:
                    return IntegralSolution(
                        is_success=False,
                        exact_latex="",
                        original_integral_latex=original_latex,
                        error_message=f"No se pudo encontrar antiderivada elemental para '{var}': {str(e)}",
                        execution_time_ms=(time.perf_counter() - start_time) * 1000
                    )
                
                # If direct antiderivative has non-elementary integral/special functions, try reversing order
                if integral.dimension == 2 and i == 1 and has_non_elementary(antiderivative):
                    reversal_sol = SymPyMultivariableSolver._try_solve_order_reversal(integral, start_time)
                    if reversal_sol is not None:
                        return reversal_sol

                antiderivative_latex = sp.latex(antiderivative)
                
                # 2. Fundamental Theorem of Calculus: F(b) - F(a)
                upper_eval = antiderivative.subs(var, upper)
                lower_eval = antiderivative.subs(var, lower)
                
                evaluated_expr = upper_eval - lower_eval
                evaluated_latex = f"\\left[{antiderivative_latex}\\right]_{{{sp.latex(lower)}}}^{{{sp.latex(upper)}}} = \\left({sp.latex(upper_eval)}\\right) - \\left({sp.latex(lower_eval)}\\right)"
                
                # 3. Algebraic simplification (resolve Piecewise definite forms cleanly when possible)
                simplified_expr = sp.simplify(evaluated_expr)
                if simplified_expr.has(sp.Piecewise):
                    definite_try = sp.simplify(sp.integrate(current_expr, (var, lower, upper)))
                    if not definite_try.has(sp.Piecewise, sp.Integral):
                        simplified_expr = definite_try
                    elif isinstance(simplified_expr, sp.Piecewise) and simplified_expr.args:
                        simplified_expr = sp.simplify(simplified_expr.args[0][0])
                simplified_latex = sp.latex(simplified_expr)
                
                # Check limits inversion (a > b)
                is_inverted = False
                try:
                    low_val = float(lower.evalf())
                    upp_val = float(upper.evalf())
                    if low_val > upp_val:
                        is_inverted = True
                except Exception:
                    is_inverted = False

                is_inner = (i == 1)
                is_outer = (i == len(integral.bounds))
                layer_label = (
                    "interna"
                    if is_inner
                    else ("externa" if is_outer else "intermedia")
                )
                step_integral_latex = f"\\int_{{{sp.latex(lower)}}}^{{{sp.latex(upper)}}} {integrand_latex} \\, d{bound.variable_str}"

                other_vars = [b.variable_str for b in integral.bounds if b.variable_str != bound.variable_str]
                if other_vars:
                    vars_str = ", ".join(other_vars)
                    constant_treatment_text = f"Tratamos a {vars_str} como constante{'s' if len(other_vars) > 1 else ''} e integramos respecto a {bound.variable_str}:"
                else:
                    constant_treatment_text = f"Integramos respecto a {bound.variable_str}:"

                antiderivative_work_latex = f"\\int {integrand_latex} \\, d{bound.variable_str} = {antiderivative_latex}"
                limits_evaluation_text = f"Ahora evaluamos en los límites {bound.variable_str} = {sp.latex(lower)} y {bound.variable_str} = {sp.latex(upper)}:"

                step_a_num = len(steps) + 1
                steps.append(
                    SolverStep(
                        step_number=step_a_num,
                        variable=bound.variable_str,
                        lower_bound_latex=sp.latex(lower),
                        upper_bound_latex=sp.latex(upper),
                        current_integrand_latex=integrand_latex,
                        antiderivative_latex=antiderivative_latex,
                        evaluated_latex=antiderivative_work_latex,
                        simplified_result_latex=antiderivative_latex,
                        explanation=(
                            f"Se calcula la antiderivada parcial respecto a '{bound.variable_str}' "
                            + (f"tratando a {vars_str} como constante{'s' if len(other_vars) > 1 else ''}." if other_vars else "aplicando las reglas elementales de integración.")
                        ),
                        applied_method="Regla de la Potencia & Fubini (Antiderivada)" if len(integral.bounds) > 1 else "Cálculo de Primitiva",
                        is_limit_inverted=False,
                        step_title=f"Paso {step_a_num}: Capa {layer_label} — antiderivada respecto a {bound.variable_str}",
                        step_integral_latex=step_integral_latex,
                        constant_treatment_text=constant_treatment_text,
                        antiderivative_work_latex=antiderivative_work_latex,
                        limits_evaluation_text=f"Primitiva obtenida respecto a {bound.variable_str}:",
                    )
                )

                if is_inverted:
                    applied_method_eval = "Propiedad de Inversión de Límites: ∫_a^b = -∫_b^a"
                    explanation_eval = (
                        f"Propiedad de Inversión de Límites: el límite inferior ({sp.latex(lower)}) es mayor que el superior ({sp.latex(upper)}). "
                        f"Se invierten los extremos a [{sp.latex(upper)}, {sp.latex(lower)}] con un factor (-1) para garantizar rigor y preservar el signo del cálculo."
                    )
                else:
                    applied_method_eval = "Teorema Fundamental del Cálculo (Regla de Barrow)"
                    explanation_eval = (
                        f"Evaluamos la primitiva entre los extremos {bound.variable_str} = {sp.latex(lower)} y {bound.variable_str} = {sp.latex(upper)} "
                        f"mediante F(b) - F(a) y simplificamos el resultado algebraico."
                    )

                step_b_num = len(steps) + 1
                steps.append(
                    SolverStep(
                        step_number=step_b_num,
                        variable=bound.variable_str,
                        lower_bound_latex=sp.latex(lower),
                        upper_bound_latex=sp.latex(upper),
                        current_integrand_latex=antiderivative_latex,
                        antiderivative_latex=antiderivative_latex,
                        evaluated_latex=evaluated_latex,
                        simplified_result_latex=simplified_latex,
                        explanation=explanation_eval,
                        applied_method=applied_method_eval,
                        is_limit_inverted=is_inverted,
                        step_title=f"Paso {step_b_num}: Capa {layer_label} — evaluación en [{sp.latex(lower)}, {sp.latex(upper)}]",
                        step_integral_latex=f"\\left[{antiderivative_latex}\\right]_{{{sp.latex(lower)}}}^{{{sp.latex(upper)}}}",
                        constant_treatment_text=f"Aplicamos la Regla de Barrow sustituyendo {bound.variable_str} = {sp.latex(upper)} y {bound.variable_str} = {sp.latex(lower)}:",
                        antiderivative_work_latex=f"\\left({sp.latex(upper_eval)}\\right) - \\left({sp.latex(lower_eval)}\\right) = {simplified_latex}",
                        limits_evaluation_text=limits_evaluation_text,
                    )
                )
                
                # Update current expression for next iterated layer
                current_expr = simplified_expr

            # Final validation of the scalar result
            final_result = sp.simplify(current_expr)
            final_latex = sp.latex(final_result)
            
            # Check for divergence or unintegrated forms
            if final_result.has(sp.oo, -sp.oo, sp.zoo, sp.nan):
                return IntegralSolution(
                    is_success=False,
                    exact_latex=final_latex,
                    steps=steps,
                    original_integral_latex=original_latex,
                    error_message="La integral diverge o produce una indeterminación/singularidad.",
                    execution_time_ms=(time.perf_counter() - start_time) * 1000
                )

            last_bound = integral.bounds[-1]
            final_step_num = len(steps) + 1
            steps.append(
                SolverStep(
                    step_number=final_step_num,
                    variable=last_bound.variable_str,
                    lower_bound_latex=sp.latex(last_bound.lower_expr),
                    upper_bound_latex=sp.latex(last_bound.upper_expr),
                    current_integrand_latex=final_latex,
                    antiderivative_latex=final_latex,
                    evaluated_latex=f"{original_latex} = {final_latex}",
                    simplified_result_latex=final_latex,
                    explanation=f"Tras completar todas las capas iteradas de Fubini y simplificar algebraicamente, el resultado simbólico exacto es {final_latex}.",
                    applied_method="Síntesis Simbólica & Verificación Final",
                    is_limit_inverted=False,
                    step_title=f"Paso {final_step_num}: Resultado exacto y verificación final",
                    step_integral_latex=f"{original_latex} = {final_latex}",
                    constant_treatment_text="Consolidación exacta de las evaluaciones iteradas:",
                    antiderivative_work_latex=f"I = {final_latex}",
                    limits_evaluation_text="Resultado simbólico definitivo:",
                )
            )

            # Compute numerical approximation
            approx_val: Optional[float] = None
            try:
                numeric_eval = complex(final_result.evalf())
                # If imaginary component is negligible or zero
                if abs(numeric_eval.imag) < 1e-12:
                    approx_val = round(float(numeric_eval.real), 6)
            except Exception:
                approx_val = None

            total_ms = (time.perf_counter() - start_time) * 1000
            
            parts = [f"{sp.latex(b.lower_expr)} \\le {b.variable_str} \\le {sp.latex(b.upper_expr)}" for b in reversed(integral.bounds)]
            region_definition = f"Esta integral está definida sobre la región donde {' y '.join(parts)}."

            formulas = [
                FormulaMethodCard(
                    name="Teorema de Fubini en ℝ³" if len(integral.bounds) == 3 else "Teorema de Fubini en el Plano",
                    formula_latex=r"\iiint_E f \, dV = \int_a^b \int_{u_1}^{u_2} \int_{w_1}^{w_2} f \, dz \, dy \, dx" if len(integral.bounds) == 3 else r"\iint_R f \, dA = \int_a^b \int_{g_1}^{g_2} f \, dy \, dx",
                    description="Permite reducir el cálculo de una integral múltiple a integrales simples iteradas secuenciales.",
                    application="Descomposición jerárquica evaluando capa por capa fijando las variables exteriores."
                ),
                FormulaMethodCard(
                    name="Teorema Fundamental del Cálculo (Regla de Barrow)",
                    formula_latex=r"\int_a^b f(x) \, dx = F(b) - F(a) \quad [F^\prime(x) = f(x)]",
                    description="Conecta la antiderivada de una función continua con la acumulación neta entre las cotas del intervalo.",
                    application="Evaluación de las primitivas en los límites superior e inferior de cada variable."
                ),
                FormulaMethodCard(
                    name="Regla de la Potencia para Antiderivadas",
                    formula_latex=r"\int u^n \, du = \frac{u^{n+1}}{n+1} + C \quad (n \ne -1)",
                    description="Fórmula analítica fundamental para integrar monomios y potencias de una variable.",
                    application="Cálculo de antiderivadas parciales manteniendo fijas las variables exteriores."
                )
            ]

            domain_info = build_domain_analysis(integral)

            return IntegralSolution(
                is_success=True,
                exact_latex=final_latex,
                approx_numeric=approx_val,
                steps=steps,
                original_integral_latex=original_latex,
                execution_time_ms=total_ms,
                region_definition=region_definition,
                formulas_and_methods=formulas,
                domain_analysis=domain_info,
            )

        except Exception as ex:
            return IntegralSolution(
                is_success=False,
                exact_latex="",
                original_integral_latex=original_latex,
                error_message=f"Error en el motor simbólico: {str(ex)}",
                execution_time_ms=(time.perf_counter() - start_time) * 1000
            )

    @classmethod
    def _try_solve_order_reversal(cls, integral: MultivariableIntegral, start_time: float) -> Optional[IntegralSolution]:
        return try_general_order_reversal(
            integral,
            cls,
            SolverStep,
            IntegralSolution,
            start_time,
        )
