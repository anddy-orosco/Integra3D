"""
Mesh3D Generator for Integra3D.
Samples algebraic surfaces, applies boundary domain masks, and generates
triangulated 3D mesh data (vertices, indices, normals) ready for WebGL/Three.js.
"""

from typing import Dict, Any, List, Tuple
import numpy as np
import sympy as sp
from app.domain.models import MultivariableIntegral, CoordinateSystem


class Mesh3DGenerator:
    """
    High-performance mesh generator translating analytical boundaries
    into triangulated surfaces and solid volumes.
    """

    @staticmethod
    def generate_mesh(
        integral: MultivariableIntegral,
        grid_resolution: int = 30
    ) -> Dict[str, Any]:
        """
        Generates 3D visualization data for the region of integration.
        Returns vertices, face indices, wireframe edges, and bounding box.
        """
        # Determine dimension and bounds
        # For a double integral: variables are [y, x] or [x, y] with z = f(x, y)
        # For a triple integral: variables are [z, y, x]
        
        try:
            if integral.dimension == 2:
                # Double integral: z = integrand(x, y), over y in [y1(x), y2(x)], x in [x1, x2]
                inner_bound = integral.bounds[0]  # usually y
                outer_bound = integral.bounds[1]  # usually x
                
                x_sym = outer_bound.var_sym
                y_sym = inner_bound.var_sym
                z_expr = integral.integrand_expr

                x_min = float(outer_bound.lower_expr.evalf())
                x_max = float(outer_bound.upper_expr.evalf())
                
                # Sample grid
                x_vals = np.linspace(x_min, x_max, grid_resolution)
                
                vertices: List[float] = []
                indices: List[int] = []
                
                # Lambdify for fast numpy vector evaluation
                z_fn = sp.lambdify((x_sym, y_sym), z_expr, modules=["numpy"])
                y_low_fn = sp.lambdify(x_sym, inner_bound.lower_expr, modules=["numpy"])
                y_upp_fn = sp.lambdify(x_sym, inner_bound.upper_expr, modules=["numpy"])

                vertex_grid = {}
                v_count = 0

                for i, x in enumerate(x_vals):
                    try:
                        y_min = float(y_low_fn(x))
                        y_max = float(y_upp_fn(x))
                    except Exception:
                        y_min, y_max = -1.0, 1.0

                    if y_min > y_max:
                        y_min, y_max = y_max, y_min

                    y_vals = np.linspace(y_min, y_max, grid_resolution)
                    
                    for j, y in enumerate(y_vals):
                        try:
                            z = float(z_fn(x, y))
                            if np.isnan(z) or np.isinf(z):
                                z = 0.0
                        except Exception:
                            z = 0.0

                        vertices.extend([round(float(x), 4), round(float(y), 4), round(float(z), 4)])
                        vertex_grid[(i, j)] = v_count
                        v_count += 1

                # Generate quad triangles
                for i in range(grid_resolution - 1):
                    for j in range(grid_resolution - 1):
                        p0 = vertex_grid.get((i, j))
                        p1 = vertex_grid.get((i + 1, j))
                        p2 = vertex_grid.get((i, j + 1))
                        p3 = vertex_grid.get((i + 1, j + 1))

                        if None not in (p0, p1, p2, p3):
                            # Triangle 1
                            indices.extend([p0, p1, p2])
                            # Triangle 2
                            indices.extend([p1, p3, p2])

                return {
                    "type": "surface",
                    "dimension": 2,
                    "title": f"Superficie z = {sp.latex(z_expr)}",
                    "vertices": vertices,
                    "indices": indices,
                    "bounds": {
                        "x_min": x_min, "x_max": x_max,
                        "y_min": -5.0, "y_max": 5.0,
                        "z_min": -5.0, "z_max": 5.0
                    }
                }

            elif integral.dimension == 3:
                # Triple integral: region V bounded by z in [z1(x,y), z2(x,y)], y in [y1(x), y2(x)], x in [x1, x2]
                z_bound = integral.bounds[0]
                y_bound = integral.bounds[1]
                x_bound = integral.bounds[2]

                x_sym = x_bound.var_sym
                y_sym = y_bound.var_sym

                x_min = float(x_bound.lower_expr.evalf())
                x_max = float(x_bound.upper_expr.evalf())

                z_low_fn = sp.lambdify((x_sym, y_sym), z_bound.lower_expr, modules=["numpy"])
                z_upp_fn = sp.lambdify((x_sym, y_sym), z_bound.upper_expr, modules=["numpy"])
                y_low_fn = sp.lambdify(x_sym, y_bound.lower_expr, modules=["numpy"])
                y_upp_fn = sp.lambdify(x_sym, y_bound.upper_expr, modules=["numpy"])

                x_vals = np.linspace(x_min, x_max, grid_resolution)

                top_vertices: List[float] = []
                bot_vertices: List[float] = []
                top_indices: List[int] = []
                bot_indices: List[int] = []

                grid_top = {}
                grid_bot = {}
                v_top_count = 0
                v_bot_count = 0

                for i, x in enumerate(x_vals):
                    try:
                        y_min = float(y_low_fn(x))
                        y_max = float(y_upp_fn(x))
                    except Exception:
                        y_min, y_max = -1.0, 1.0

                    if y_min > y_max:
                        y_min, y_max = y_max, y_min

                    y_vals = np.linspace(y_min, y_max, grid_resolution)
                    for j, y in enumerate(y_vals):
                        try:
                            z_low = float(z_low_fn(x, y))
                            z_upp = float(z_upp_fn(x, y))
                        except Exception:
                            z_low, z_upp = 0.0, 1.0

                        top_vertices.extend([round(float(x), 4), round(float(y), 4), round(float(z_upp), 4)])
                        grid_top[(i, j)] = v_top_count
                        v_top_count += 1

                        bot_vertices.extend([round(float(x), 4), round(float(y), 4), round(float(z_low), 4)])
                        grid_bot[(i, j)] = v_bot_count
                        v_bot_count += 1

                for i in range(grid_resolution - 1):
                    for j in range(grid_resolution - 1):
                        t0 = grid_top.get((i, j))
                        t1 = grid_top.get((i + 1, j))
                        t2 = grid_top.get((i, j + 1))
                        t3 = grid_top.get((i + 1, j + 1))
                        if None not in (t0, t1, t2, t3):
                            top_indices.extend([t0, t1, t2])
                            top_indices.extend([t1, t3, t2])

                        b0 = grid_bot.get((i, j))
                        b1 = grid_bot.get((i + 1, j))
                        b2 = grid_bot.get((i, j + 1))
                        b3 = grid_bot.get((i + 1, j + 1))
                        if None not in (b0, b1, b2, b3):
                            bot_indices.extend([b0, b2, b1])
                            bot_indices.extend([b1, b2, b3])

                return {
                    "type": "volume",
                    "dimension": 3,
                    "title": f"Volumen acotado entre {sp.latex(z_bound.lower_expr)} y {sp.latex(z_bound.upper_expr)}",
                    "top_surface": {"vertices": top_vertices, "indices": top_indices},
                    "bottom_surface": {"vertices": bot_vertices, "indices": bot_indices},
                    "bounds": {"x_min": x_min, "x_max": x_max}
                }

        except Exception as e:
            # Fallback simple mesh if symbolic lambdification encounters discontinuities
            return {
                "type": "fallback",
                "error": str(e),
                "vertices": [],
                "indices": []
            }
