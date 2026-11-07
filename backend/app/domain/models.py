"""
Domain models for Integra3D mathematical engine.
Implements OOP principles and Python dunder methods for mathematical representations.
"""

from enum import Enum
from typing import List, Optional, Tuple, Dict, Any
import sympy as sp


class CoordinateSystem(str, Enum):
    CARTESIAN = "cartesian"      # (x, y, z)
    CYLINDRICAL = "cylindrical"  # (r, theta, z) -> J = r
    SPHERICAL = "spherical"      # (rho, theta, phi) -> J = rho^2 * sin(phi)


class IntegrationBound:
    """
    Represents the limits of integration for a single variable: [lower, upper].
    Can be constant values (e.g., 0, 1) or algebraic expressions (e.g., sqrt(1 - x**2)).
    """
    def __init__(self, variable: str, lower: str, upper: str):
        self.variable_str = variable.strip()
        self.var_sym = sp.Symbol(self.variable_str)
        self.lower_str = lower.strip()
        self.upper_str = upper.strip()
        
        # Parse into SymPy expressions
        self.lower_expr = sp.sympify(self.lower_str)
        self.upper_expr = sp.sympify(self.upper_str)

    def __repr__(self) -> str:
        return f"IntegrationBound({self.variable_str}: [{self.lower_str}, {self.upper_str}])"

    def __str__(self) -> str:
        return f"{self.lower_str} <= {self.variable_str} <= {self.upper_str}"

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, IntegrationBound):
            return False
        return (
            self.variable_str == other.variable_str and
            self.lower_expr == other.lower_expr and
            self.upper_expr == other.upper_expr
        )

    def to_latex(self) -> str:
        return f"{sp.latex(self.lower_expr)} \\le {self.variable_str} \\le {sp.latex(self.upper_expr)}"


class MultivariableIntegral:
    """
    Object-oriented representation of a double or triple integral.
    Encapsulates integrand, integration order, coordinate system, and limits.
    """
    def __init__(
        self,
        integrand: str,
        bounds: List[IntegrationBound],
        coordinate_system: CoordinateSystem = CoordinateSystem.CARTESIAN
    ):
        self.integrand_str = integrand.strip()
        self.integrand_expr = sp.sympify(self.integrand_str)
        self.bounds = bounds
        self.coordinate_system = coordinate_system
        self._validate()

    def _validate(self) -> None:
        dim = len(self.bounds)
        if dim not in (2, 3):
            raise ValueError(f"Integra3D soporta integrales dobles (2D) y triples (3D). Recibido: {dim} dimensiones.")

    @property
    def dimension(self) -> int:
        return len(self.bounds)

    @property
    def variables(self) -> List[str]:
        return [b.variable_str for b in self.bounds]

    def jacobian_factor(self) -> sp.Expr:
        """Returns the differential volume element factor based on coordinate system."""
        if self.coordinate_system == CoordinateSystem.CYLINDRICAL:
            # dV = r dz dr d(theta)
            return sp.Symbol('r')
        elif self.coordinate_system == CoordinateSystem.SPHERICAL:
            # dV = rho^2 * sin(phi) d(rho) d(phi) d(theta)
            rho = sp.Symbol('rho')
            phi = sp.Symbol('phi')
            return rho**2 * sp.sin(phi)
        return sp.Integer(1)

    def effective_integrand(self) -> sp.Expr:
        """Integrand multiplied by the coordinate system's Jacobian factor."""
        j = self.jacobian_factor()
        return sp.simplify(self.integrand_expr * j)

    # --- Dunder Methods ---

    def __len__(self) -> int:
        """Dimension of the integral (2 for double, 3 for triple)."""
        return self.dimension

    def __getitem__(self, index: int) -> IntegrationBound:
        """Access bound by iteration index."""
        return self.bounds[index]

    def __call__(self, **kwargs) -> float:
        """Numerically evaluate the integrand at a given point (e.g. x=1, y=2, z=3)."""
        subs_dict = {sp.Symbol(k): v for k, v in kwargs.items()}
        return float(self.integrand_expr.evalf(subs=subs_dict))

    def __repr__(self) -> str:
        bounds_repr = ", ".join(repr(b) for b in self.bounds)
        return f"MultivariableIntegral(integrand='{self.integrand_str}', bounds=[{bounds_repr}], coords={self.coordinate_system})"

    def __str__(self) -> str:
        differential = " ".join(f"d{b.variable_str}" for b in self.bounds)
        return f"Integral_{len(self)} ({self.integrand_str}) {differential}"

    def to_latex(self) -> str:
        """Generates academic-quality LaTeX for the unevaluated iterated integral."""
        int_symbols = ""
        # In iterated integral notation: leftmost integral has the outermost limit
        for b in reversed(self.bounds):
            int_symbols += f"\\int_{{{sp.latex(b.lower_expr)}}}^{{{sp.latex(b.upper_expr)}}} "
        
        diffs = "".join(f"\\,d{b.variable_str}" for b in self.bounds)
        integrand_latex = sp.latex(self.integrand_expr)
        
        if self.coordinate_system != CoordinateSystem.CARTESIAN:
            j = self.jacobian_factor()
            if j != 1:
                return f"{int_symbols} \\left( {integrand_latex} \\cdot {sp.latex(j)} \\right) {diffs}"
        
        return f"{int_symbols} {integrand_latex} {diffs}"
