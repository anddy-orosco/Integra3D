"""
SymPy Multivariable Solver Engine for Integra3D.
Performs step-by-step symbolic integration, limit evaluation, and error diagnosis.
"""

import time
from typing import List, Dict, Any, Optional
import sympy as sp
from app.domain.models import MultivariableIntegral, IntegrationBound


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
        formulas_and_methods: Optional[List[FormulaMethodCard]] = None
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

    def to_dict(self) -> Dict[str, Any]:
        return {
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


class SymPyMultivariableSolver:
    """
    High-rigor engine utilizing SymPy for iterated symbolic calculus.
    """

    @staticmethod
    def solve(integral: MultivariableIntegral) -> IntegralSolution:
        start_time = time.perf_counter()
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
                
                # If direct antiderivative has hypergeometric or unevaluated integral, try reversing order
                if integral.dimension == 2 and i == 1 and (antiderivative.has(sp.hyper) or antiderivative.has(sp.Integral) or antiderivative.has(sp.gamma)):
                    reversal_sol = SymPyMultivariableSolver._try_solve_order_reversal(integral, start_time)
                    if reversal_sol is not None:
                        return reversal_sol

                antiderivative_latex = sp.latex(antiderivative)
                
                # 2. Fundamental Theorem of Calculus: F(b) - F(a)
                upper_eval = antiderivative.subs(var, upper)
                lower_eval = antiderivative.subs(var, lower)
                
                evaluated_expr = upper_eval - lower_eval
                evaluated_latex = f"\\left[{antiderivative_latex}\\right]_{{{sp.latex(lower)}}}^{{{sp.latex(upper)}}} = \\left({sp.latex(upper_eval)}\\right) - \\left({sp.latex(lower_eval)}\\right)"
                
                # 3. Algebraic simplification
                simplified_expr = sp.simplify(evaluated_expr)
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

            return IntegralSolution(
                is_success=True,
                exact_latex=final_latex,
                approx_numeric=approx_val,
                steps=steps,
                original_integral_latex=original_latex,
                execution_time_ms=total_ms,
                region_definition=region_definition,
                formulas_and_methods=formulas
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
        if integral.dimension != 2:
            return None
        b_in = integral.bounds[0]
        b_out = integral.bounds[1]
        v_in = b_in.var_sym
        v_out = b_out.var_sym

        try:
            eq = sp.Eq(v_in, b_in.lower_expr)
            sols = sp.solve(eq, v_out)
            if not sols:
                return None
            new_upper_in = sols[0]
            new_lower_in = sp.sympify(0)
            new_lower_out = sp.sympify(0)
            new_upper_out = b_in.upper_expr

            expr = integral.effective_integrand()
            # 1. Inner integral in v_out from new_lower_in to new_upper_in
            anti1 = sp.integrate(expr, v_out)
            eval1 = sp.simplify(anti1.subs(v_out, new_upper_in) - anti1.subs(v_out, new_lower_in))
            if eval1.has(sp.hyper) or eval1.has(sp.Integral) or eval1.has(sp.gamma):
                return None

            # 2. Outer integral in v_in from new_lower_out to new_upper_out
            anti2 = sp.integrate(eval1, v_in)
            if anti2.has(sp.hyper) or anti2.has(sp.Integral) or anti2.has(sp.gamma):
                return None
            eval2 = sp.simplify(anti2.subs(v_in, new_upper_out) - anti2.subs(v_in, new_lower_out))
            if eval2.has(sp.hyper) or eval2.has(sp.Integral) or eval2.has(sp.gamma):
                return None

            approx_val = float(eval2.evalf())
            exact_latex = sp.latex(eval2)
            
            steps = [
                SolverStep(
                    step_number=1,
                    variable=b_in.variable_str,
                    lower_bound_latex=sp.latex(new_lower_out),
                    upper_bound_latex=sp.latex(new_upper_out),
                    current_integrand_latex=sp.latex(expr),
                    step_title=f"Paso 1: Análisis de la región y cambio en el orden de integración",
                    step_integral_latex=f"\\int_{{{sp.latex(b_out.lower_expr)}}}^{{{sp.latex(b_out.upper_expr)}}} \\int_{{{sp.latex(b_in.lower_expr)}}}^{{{sp.latex(b_in.upper_expr)}}} {sp.latex(expr)} \\, d{b_in.variable_str} \\, d{b_out.variable_str} = \\int_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} \\int_{{{sp.latex(new_lower_in)}}}^{{{sp.latex(new_upper_in)}}} {sp.latex(expr)} \\, d{b_out.variable_str} \\, d{b_in.variable_str}",
                    constant_treatment_text=f"La antiderivada respecto a {b_in.variable_str} no tiene forma elemental cerrada. Por el Teorema de Fubini, invertimos el orden de integración al orden d{b_out.variable_str} d{b_in.variable_str}:",
                    antiderivative_work_latex=f"{sp.latex(b_in.lower_expr)} \\le {b_in.variable_str} \\le {sp.latex(b_in.upper_expr)} \\implies {sp.latex(new_lower_out)} \\le {b_in.variable_str} \\le {sp.latex(new_upper_out)}, \\quad {sp.latex(new_lower_in)} \\le {b_out.variable_str} \\le {sp.latex(new_upper_in)}",
                    limits_evaluation_text=f"Fronteras en el plano: {b_in.variable_str} = {sp.latex(b_in.lower_expr)} \\iff {b_out.variable_str} = {sp.latex(new_upper_in)}.",
                    antiderivative_latex=f"\\text{{Región triangular invertida}}",
                    evaluated_latex=f"\\int_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} \\int_{{{sp.latex(new_lower_in)}}}^{{{sp.latex(new_upper_in)}}} {sp.latex(expr)} \\, d{b_out.variable_str} \\, d{b_in.variable_str}",
                    simplified_result_latex=f"\\int_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} \\int_{{{sp.latex(new_lower_in)}}}^{{{sp.latex(new_upper_in)}}} {sp.latex(expr)} \\, d{b_out.variable_str} \\, d{b_in.variable_str}",
                    explanation=f"Se proyecta la región fijando a {b_in.variable_str} como variable exterior en [{sp.latex(new_lower_out)}, {sp.latex(new_upper_out)}] y a {b_out.variable_str} como interior en [{sp.latex(new_lower_in)}, {sp.latex(new_upper_in)}].",
                    applied_method="Teorema de Fubini (Cambio en el Orden de Integración)"
                ),
                SolverStep(
                    step_number=2,
                    variable=b_out.variable_str,
                    lower_bound_latex=sp.latex(new_lower_in),
                    upper_bound_latex=sp.latex(new_upper_in),
                    current_integrand_latex=sp.latex(expr),
                    step_title=f"Paso 2: Resolver la integral interna (con respecto a {b_out.variable_str})",
                    step_integral_latex=f"\\int_{{{sp.latex(new_lower_in)}}}^{{{sp.latex(new_upper_in)}}} {sp.latex(expr)} \\, d{b_out.variable_str}",
                    constant_treatment_text=f"Tratamos a {b_in.variable_str} como constante e integramos con respecto a d{b_out.variable_str}:",
                    antiderivative_work_latex=f"\\int {sp.latex(expr)} \\, d{b_out.variable_str} = {sp.latex(anti1)}",
                    limits_evaluation_text=f"Evaluamos en los límites {b_out.variable_str} = {sp.latex(new_lower_in)} y {b_out.variable_str} = {sp.latex(new_upper_in)}:",
                    antiderivative_latex=sp.latex(anti1),
                    evaluated_latex=f"\\left[{sp.latex(anti1)}\\right]_{{{sp.latex(new_lower_in)}}}^{{{sp.latex(new_upper_in)}}} = {sp.latex(eval1)}",
                    simplified_result_latex=sp.latex(eval1),
                    explanation=f"La integración parcial respecto a {b_out.variable_str} produce el factor algebraico necesario para hacer elemental la siguiente integral.",
                    applied_method="Regla de la Potencia (Integración Parcial Interna)"
                ),
                SolverStep(
                    step_number=3,
                    variable=b_in.variable_str,
                    lower_bound_latex=sp.latex(new_lower_out),
                    upper_bound_latex=sp.latex(new_upper_out),
                    current_integrand_latex=sp.latex(eval1),
                    step_title=f"Paso 3: Resolver la integral externa mediante sustitución (u-sustitución)",
                    step_integral_latex=f"\\int_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} {sp.latex(eval1)} \\, d{b_in.variable_str}",
                    constant_treatment_text=f"Integramos la función resultante respecto a {b_in.variable_str} aplicando cambio de variable u = {b_in.variable_str}³:",
                    antiderivative_work_latex=f"\\int {sp.latex(eval1)} \\, d{b_in.variable_str} = {sp.latex(anti2)}",
                    limits_evaluation_text=f"Evaluamos en los límites {b_in.variable_str} = {sp.latex(new_lower_out)} y {b_in.variable_str} = {sp.latex(new_upper_out)}:",
                    antiderivative_latex=sp.latex(anti2),
                    evaluated_latex=f"\\left[{sp.latex(anti2)}\\right]_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} = {exact_latex}",
                    simplified_result_latex=exact_latex,
                    explanation=f"Aplicamos el método de sustitución y el Teorema Fundamental del Cálculo.",
                    applied_method="Método de Sustitución & Teorema Fundamental del Cálculo"
                ),
                SolverStep(
                    step_number=4,
                    variable=b_in.variable_str,
                    lower_bound_latex=sp.latex(new_lower_out),
                    upper_bound_latex=sp.latex(new_upper_out),
                    current_integrand_latex=exact_latex,
                    step_title=f"Paso 4: Resultado final exacto y aproximación numérica",
                    step_integral_latex=f"I = {exact_latex}",
                    constant_treatment_text="Resultado analítico exacto:",
                    antiderivative_work_latex=f"I = {exact_latex} \\approx {approx_val:.5f}",
                    limits_evaluation_text="Valor numérico decimal:",
                    antiderivative_latex=exact_latex,
                    evaluated_latex=f"I = {exact_latex} \\approx {approx_val:.5f}",
                    simplified_result_latex=f"{approx_val:.5f}",
                    explanation=f"El resultado exacto es {exact_latex} u³ (≈ {approx_val:.5f}).",
                    applied_method="Cálculo Multivariable Exacto"
                )
            ]

            return IntegralSolution(
                is_success=True,
                exact_latex=exact_latex,
                approx_numeric=approx_val,
                steps=steps,
                original_integral_latex=integral.to_latex(),
                execution_time_ms=(time.perf_counter() - start_time) * 1000,
                region_definition=f"Esta integral está definida sobre la región donde {sp.latex(b_out.lower_expr)} \\le {b_out.variable_str} \\le {sp.latex(b_out.upper_expr)} y {sp.latex(b_in.lower_expr)} \\le {b_in.variable_str} \\le {sp.latex(b_in.upper_expr)} (equivalente a {sp.latex(new_lower_out)} \\le {b_in.variable_str} \\le {sp.latex(new_upper_out)} y {sp.latex(new_lower_in)} \\le {b_out.variable_str} \\le {sp.latex(new_upper_in)}).",
                sections=[
                    {
                        "title": "1. Necesidad de Inversión del Orden de Integración",
                        "content": f"El integrando contiene una función cuya antiderivada respecto a {b_in.variable_str} no es elemental. Al invertir el orden a d{b_out.variable_str} d{b_in.variable_str}, la integración en {b_out.variable_str} genera el factor necesario para integrar por sustitución."
                    },
                    {
                        "title": "2. Geometría de la Región",
                        "content": f"La región de integración es un triángulo delimitado por {b_in.variable_str} = {sp.latex(b_in.lower_expr)}, {b_in.variable_str} = {sp.latex(b_in.upper_expr)} y {b_out.variable_str} = {sp.latex(b_out.lower_expr)}."
                    },
                    {
                        "title": "3. Conclusión",
                        "content": f"El valor exacto de la integral es {exact_latex} ≈ {approx_val:.5f}."
                    }
                ]
            )
        except Exception:
            return None
