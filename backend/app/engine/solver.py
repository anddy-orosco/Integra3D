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
        explanation: str
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
            "explanation": self.explanation
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
        execution_time_ms: float = 0.0
    ):
        self.is_success = is_success
        self.exact_latex = exact_latex
        self.approx_numeric = approx_numeric
        self.steps = steps or []
        self.original_integral_latex = original_integral_latex
        self.error_message = error_message
        self.execution_time_ms = execution_time_ms

    def to_dict(self) -> Dict[str, Any]:
        return {
            "is_success": self.is_success,
            "exact_latex": self.exact_latex,
            "approx_numeric": self.approx_numeric,
            "steps": [s.to_dict() for s in self.steps],
            "original_integral_latex": self.original_integral_latex,
            "error_message": self.error_message,
            "execution_time_ms": self.execution_time_ms
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
                
                antiderivative_latex = sp.latex(antiderivative)
                
                # 2. Fundamental Theorem of Calculus: F(b) - F(a)
                upper_eval = antiderivative.subs(var, upper)
                lower_eval = antiderivative.subs(var, lower)
                
                evaluated_expr = upper_eval - lower_eval
                evaluated_latex = f"\\left[{antiderivative_latex}\\right]_{{{sp.latex(lower)}}}^{{{sp.latex(upper)}}} = \\left({sp.latex(upper_eval)}\\right) - \\left({sp.latex(lower_eval)}\\right)"
                
                # 3. Algebraic simplification
                simplified_expr = sp.simplify(evaluated_expr)
                simplified_latex = sp.latex(simplified_expr)
                
                explanation = (
                    f"Paso {i}: Se integra con respecto a '{bound.variable_str}' tratando las demás variables como constantes. "
                    f"Luego se evalúan los límites [{sp.latex(lower)}, {sp.latex(upper)}] mediante el Teorema Fundamental del Cálculo."
                )
                
                steps.append(
                    SolverStep(
                        step_number=i,
                        variable=bound.variable_str,
                        lower_bound_latex=sp.latex(lower),
                        upper_bound_latex=sp.latex(upper),
                        current_integrand_latex=integrand_latex,
                        antiderivative_latex=antiderivative_latex,
                        evaluated_latex=evaluated_latex,
                        simplified_result_latex=simplified_latex,
                        explanation=explanation
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
            
            return IntegralSolution(
                is_success=True,
                exact_latex=final_latex,
                approx_numeric=approx_val,
                steps=steps,
                original_integral_latex=original_latex,
                execution_time_ms=total_ms
            )

        except Exception as ex:
            return IntegralSolution(
                is_success=False,
                exact_latex="",
                original_integral_latex=original_latex,
                error_message=f"Error en el motor simbólico: {str(ex)}",
                execution_time_ms=(time.perf_counter() - start_time) * 1000
            )
