"""
Mesh3D Generator for Integra3D.
Samples algebraic surfaces, applies boundary domain masks, and generates
triangulated 3D mesh data (vertices, indices, normals) ready for WebGL/Three.js.
"""

from typing import Dict, Any, List, Tuple
import numpy as np
import sympy as sp
from app.domain.models import MultivariableIntegral, CoordinateSystem, POSITIVE_PARAM_NAMES, parse_sympy_expr


PREVIEW_PARAMS: Dict[str, float] = {
    "a": 2.0, "b": 3.0, "c": 2.5, "m": 2.0, "n": 2.0, "R": 2.0, "H": 3.0, "k": 1.0,
}


def _sub_preview(expr: sp.Expr) -> sp.Expr:
    subs_map = {}
    for sym in expr.free_symbols:
        if sym.name in PREVIEW_PARAMS:
            subs_map[sym] = PREVIEW_PARAMS[sym.name]
    return expr.subs(subs_map) if subs_map else expr


class Mesh3DGenerator:
    """
    High-performance mesh generator translating analytical boundaries
    into triangulated surfaces, dual volume bounds, and z=0 domain projections.
    """

    @staticmethod
    def _build_tri_indices(grid_map: Dict[Tuple[int, int], int], n_i: int, n_j: int, reverse_winding: bool = False) -> List[int]:
        idx: List[int] = []
        for i in range(n_i - 1):
            for j in range(n_j - 1):
                p0 = grid_map.get((i, j))
                p1 = grid_map.get((i + 1, j))
                p2 = grid_map.get((i, j + 1))
                p3 = grid_map.get((i + 1, j + 1))
                if None not in (p0, p1, p2, p3):
                    if reverse_winding:
                        idx.extend([p0, p2, p1, p1, p2, p3])
                    else:
                        idx.extend([p0, p1, p2, p1, p3, p2])
        return idx

    @staticmethod
    def _extract_cartesian_projection(inner_b, outer_b, grid_res: int) -> List[float]:
        """Samples the 2D boundary loop on z=0 as [x0, y0, 0, x1, y1, 0, ...]."""
        out_sym = outer_b.var_sym
        low_fn = sp.lambdify(out_sym, _sub_preview(inner_b.lower_expr), modules=["numpy"])
        upp_fn = sp.lambdify(out_sym, _sub_preview(inner_b.upper_expr), modules=["numpy"])
        o_min = float(_sub_preview(outer_b.lower_expr).evalf())
        o_max = float(_sub_preview(outer_b.upper_expr).evalf())
        if o_min > o_max:
            o_min, o_max = o_max, o_min
        o_vals = np.linspace(o_min, o_max, max(12, grid_res))
        upper_pts: List[Tuple[float, float]] = []
        lower_pts: List[Tuple[float, float]] = []
        for ov in o_vals:
            try:
                lo = float(low_fn(ov))
                hi = float(upp_fn(ov))
                if np.isnan(lo) or np.isnan(hi):
                    continue
                if outer_b.variable_str == "x":
                    upper_pts.append((float(ov), hi))
                    lower_pts.append((float(ov), lo))
                else:
                    upper_pts.append((hi, float(ov)))
                    lower_pts.append((lo, float(ov)))
            except Exception:
                continue
        loop = upper_pts + list(reversed(lower_pts))
        flat: List[float] = []
        for px, py in loop:
            flat.extend([round(px, 4), round(py, 4), 0.0])
        return flat

    @staticmethod
    def generate_mesh(
        integral: MultivariableIntegral,
        grid_resolution: int = 30
    ) -> Dict[str, Any]:
        """
        Generates 3D visualization data for the region of integration.
        Returns vertices, face indices, dual surfaces (top/bottom), and z=0 domain projection.
        """
        try:
            coord = integral.coordinate_system
            if coord == CoordinateSystem.POLAR and integral.dimension == 2:
                return Mesh3DGenerator._generate_polar_mesh(integral, grid_resolution)
            if coord == CoordinateSystem.CYLINDRICAL and integral.dimension == 3:
                return Mesh3DGenerator._generate_cylindrical_mesh(integral, grid_resolution)
            if coord == CoordinateSystem.SPHERICAL and integral.dimension == 3:
                return Mesh3DGenerator._generate_spherical_mesh(integral, grid_resolution)

            if integral.dimension == 2 and getattr(integral, "problem_mode", "direct") == "volume_between_surfaces":
                return Mesh3DGenerator._generate_dual_surface_2d(integral, grid_resolution)

            if integral.dimension == 2:
                # Double integral: z = integrand(x, y)
                inner_bound = integral.bounds[0]
                outer_bound = integral.bounds[1]
                
                x_sym = outer_bound.var_sym
                y_sym = inner_bound.var_sym
                z_expr = _sub_preview(integral.integrand_expr)

                x_min = float(_sub_preview(outer_bound.lower_expr).evalf())
                x_max = float(_sub_preview(outer_bound.upper_expr).evalf())
                if x_min > x_max:
                    x_min, x_max = x_max, x_min
                
                x_vals = np.linspace(x_min, x_max, grid_resolution)
                vertices: List[float] = []
                
                z_fn = sp.lambdify((x_sym, y_sym), z_expr, modules=["numpy"])
                y_low_fn = sp.lambdify(x_sym, _sub_preview(inner_bound.lower_expr), modules=["numpy"])
                y_upp_fn = sp.lambdify(x_sym, _sub_preview(inner_bound.upper_expr), modules=["numpy"])

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

                        if outer_bound.variable_str == "y":
                            vertices.extend([round(float(y), 4), round(float(x), 4), round(float(z), 4)])
                        else:
                            vertices.extend([round(float(x), 4), round(float(y), 4), round(float(z), 4)])
                        vertex_grid[(i, j)] = v_count
                        v_count += 1

                indices = Mesh3DGenerator._build_tri_indices(vertex_grid, grid_resolution, grid_resolution)
                projection = Mesh3DGenerator._extract_cartesian_projection(inner_bound, outer_bound, grid_resolution)

                return {
                    "type": "surface",
                    "dimension": 2,
                    "title": f"Superficie z = {sp.latex(integral.integrand_expr)}",
                    "vertices": vertices,
                    "indices": indices,
                    "domain_projection": projection,
                    "bounds": {
                        "x_min": x_min, "x_max": x_max,
                        "y_min": -5.0, "y_max": 5.0,
                        "z_min": -5.0, "z_max": 5.0
                    }
                }

            elif integral.dimension == 3:
                # Triple integral Cartesian
                z_bound = integral.bounds[0]
                y_bound = integral.bounds[1]
                x_bound = integral.bounds[2]

                x_sym = x_bound.var_sym
                y_sym = y_bound.var_sym

                x_min = float(_sub_preview(x_bound.lower_expr).evalf())
                x_max = float(_sub_preview(x_bound.upper_expr).evalf())
                if x_min > x_max:
                    x_min, x_max = x_max, x_min

                z_low_fn = sp.lambdify((x_sym, y_sym), _sub_preview(z_bound.lower_expr), modules=["numpy"])
                z_upp_fn = sp.lambdify((x_sym, y_sym), _sub_preview(z_bound.upper_expr), modules=["numpy"])
                y_low_fn = sp.lambdify(x_sym, _sub_preview(y_bound.lower_expr), modules=["numpy"])
                y_upp_fn = sp.lambdify(x_sym, _sub_preview(y_bound.upper_expr), modules=["numpy"])

                x_vals = np.linspace(x_min, x_max, grid_resolution)

                top_vertices: List[float] = []
                bot_vertices: List[float] = []
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

                top_indices = Mesh3DGenerator._build_tri_indices(grid_top, grid_resolution, grid_resolution)
                bot_indices = Mesh3DGenerator._build_tri_indices(grid_bot, grid_resolution, grid_resolution, reverse_winding=True)
                projection = Mesh3DGenerator._extract_cartesian_projection(y_bound, x_bound, grid_resolution)

                return {
                    "type": "volume",
                    "dimension": 3,
                    "title": f"Volumen acotado entre {sp.latex(z_bound.lower_expr)} y {sp.latex(z_bound.upper_expr)}",
                    "top_surface": {"vertices": top_vertices, "indices": top_indices},
                    "bottom_surface": {"vertices": bot_vertices, "indices": bot_indices},
                    "domain_projection": projection,
                    "bounds": {"x_min": x_min, "x_max": x_max}
                }

        except Exception as e:
            return {
                "type": "fallback",
                "error": str(e),
                "vertices": [],
                "indices": []
            }

    @staticmethod
    def _generate_dual_surface_2d(integral: MultivariableIntegral, grid_resolution: int) -> Dict[str, Any]:
        y_bound, x_bound = integral.bounds[0], integral.bounds[1]
        x_sym, y_sym = x_bound.var_sym, y_bound.var_sym
        z_sup_e = _sub_preview(parse_sympy_expr(integral.z_upper_expr or integral.integrand_str))
        z_inf_e = _sub_preview(parse_sympy_expr(integral.z_lower_expr or "0"))
        z_sup_fn = sp.lambdify((x_sym, y_sym), z_sup_e, modules=["numpy"])
        z_inf_fn = sp.lambdify((x_sym, y_sym), z_inf_e, modules=["numpy"])
        y_lo_fn = sp.lambdify(x_sym, _sub_preview(y_bound.lower_expr), modules=["numpy"])
        y_hi_fn = sp.lambdify(x_sym, _sub_preview(y_bound.upper_expr), modules=["numpy"])
        x_min = float(_sub_preview(x_bound.lower_expr).evalf())
        x_max = float(_sub_preview(x_bound.upper_expr).evalf())
        if x_min > x_max:
            x_min, x_max = x_max, x_min
        x_vals = np.linspace(x_min, x_max, grid_resolution)
        top_v: List[float] = []
        bot_v: List[float] = []
        g_top, g_bot = {}, {}
        vt = vb = 0
        for i, x in enumerate(x_vals):
            try:
                y0, y1 = float(y_lo_fn(x)), float(y_hi_fn(x))
            except Exception:
                y0, y1 = -1.0, 1.0
            if y0 > y1:
                y0, y1 = y1, y0
            for j, y in enumerate(np.linspace(y0, y1, grid_resolution)):
                try:
                    zu, zl = float(z_sup_fn(x, y)), float(z_inf_fn(x, y))
                except Exception:
                    zu, zl = 1.0, 0.0
                top_v.extend([round(float(x), 4), round(float(y), 4), round(zu, 4)])
                bot_v.extend([round(float(x), 4), round(float(y), 4), round(zl, 4)])
                g_top[(i, j)] = vt
                g_bot[(i, j)] = vb
                vt += 1
                vb += 1
        return {
            "type": "volume",
            "dimension": 3,
            "title": "Sólido V entre z_inf y z_sup",
            "top_surface": {"vertices": top_v, "indices": Mesh3DGenerator._build_tri_indices(g_top, grid_resolution, grid_resolution)},
            "bottom_surface": {"vertices": bot_v, "indices": Mesh3DGenerator._build_tri_indices(g_bot, grid_resolution, grid_resolution, True)},
            "domain_projection": Mesh3DGenerator._extract_cartesian_projection(y_bound, x_bound, grid_resolution),
            "bounds": {"x_min": x_min, "x_max": x_max},
        }

    @staticmethod
    def _generate_polar_mesh(integral: MultivariableIntegral, grid_res: int) -> Dict[str, Any]:
        r_b, th_b = integral.bounds[0], integral.bounds[1]
        r_sym, th_sym = sp.Symbol("r"), sp.Symbol("theta")
        th_min = float(_sub_preview(th_b.lower_expr).evalf())
        th_max = float(_sub_preview(th_b.upper_expr).evalf())
        r_lo_fn = sp.lambdify(th_sym, _sub_preview(r_b.lower_expr), modules=["numpy"])
        r_hi_fn = sp.lambdify(th_sym, _sub_preview(r_b.upper_expr), modules=["numpy"])
        z_fn = sp.lambdify((r_sym, th_sym), _sub_preview(integral.integrand_expr), modules=["numpy"])
        verts: List[float] = []
        proj: List[float] = []
        grid = {}
        vc = 0
        for i, th in enumerate(np.linspace(th_min, th_max, grid_res)):
            try:
                r0, r1 = max(0.0, float(r_lo_fn(th))), max(0.0, float(r_hi_fn(th)))
            except Exception:
                r0, r1 = 0.0, 2.0
            proj.extend([round(r1 * float(np.cos(th)), 4), round(r1 * float(np.sin(th)), 4), 0.0])
            for j, rr in enumerate(np.linspace(r0, r1, grid_res)):
                px, py = rr * float(np.cos(th)), rr * float(np.sin(th))
                try:
                    pz = float(z_fn(rr, th))
                except Exception:
                    pz = 0.0
                verts.extend([round(px, 4), round(py, 4), round(pz, 4)])
                grid[(i, j)] = vc
                vc += 1
        return {
            "type": "surface",
            "dimension": 2,
            "title": f"Superficie Polar z = {sp.latex(integral.integrand_expr)}",
            "vertices": verts,
            "indices": Mesh3DGenerator._build_tri_indices(grid, grid_res, grid_res),
            "domain_projection": proj,
        }

    @staticmethod
    def _generate_cylindrical_mesh(integral: MultivariableIntegral, grid_res: int) -> Dict[str, Any]:
        z_b, r_b, th_b = integral.bounds[0], integral.bounds[1], integral.bounds[2]
        r_sym, th_sym = sp.Symbol("r"), sp.Symbol("theta")
        th_min = float(_sub_preview(th_b.lower_expr).evalf())
        th_max = float(_sub_preview(th_b.upper_expr).evalf())
        r_lo_fn = sp.lambdify(th_sym, _sub_preview(r_b.lower_expr), modules=["numpy"])
        r_hi_fn = sp.lambdify(th_sym, _sub_preview(r_b.upper_expr), modules=["numpy"])
        z_lo_fn = sp.lambdify((r_sym, th_sym), _sub_preview(z_b.lower_expr), modules=["numpy"])
        z_hi_fn = sp.lambdify((r_sym, th_sym), _sub_preview(z_b.upper_expr), modules=["numpy"])
        top_v, bot_v, proj = [], [], []
        g_top, g_bot = {}, {}
        vt = vb = 0
        for i, th in enumerate(np.linspace(th_min, th_max, grid_res)):
            r0, r1 = float(r_lo_fn(th)), float(r_hi_fn(th))
            proj.extend([round(r1 * float(np.cos(th)), 4), round(r1 * float(np.sin(th)), 4), 0.0])
            for j, rr in enumerate(np.linspace(r0, r1, grid_res)):
                px, py = rr * float(np.cos(th)), rr * float(np.sin(th))
                try:
                    zl, zu = float(z_lo_fn(rr, th)), float(z_hi_fn(rr, th))
                except Exception:
                    zl, zu = 0.0, 1.0
                top_v.extend([round(px, 4), round(py, 4), round(zu, 4)])
                bot_v.extend([round(px, 4), round(py, 4), round(zl, 4)])
                g_top[(i, j)] = vt
                g_bot[(i, j)] = vb
                vt += 1
                vb += 1
        return {
            "type": "volume",
            "dimension": 3,
            "title": "Sólido Cilíndrico V",
            "top_surface": {"vertices": top_v, "indices": Mesh3DGenerator._build_tri_indices(g_top, grid_res, grid_res)},
            "bottom_surface": {"vertices": bot_v, "indices": Mesh3DGenerator._build_tri_indices(g_bot, grid_res, grid_res, True)},
            "domain_projection": proj,
        }

    @staticmethod
    def _generate_spherical_mesh(integral: MultivariableIntegral, grid_res: int) -> Dict[str, Any]:
        rho_b, phi_b, th_b = integral.bounds[0], integral.bounds[1], integral.bounds[2]
        ph_sym, th_sym = sp.Symbol("phi"), sp.Symbol("theta")
        ph_lo = float(_sub_preview(phi_b.lower_expr).evalf())
        ph_hi = float(_sub_preview(phi_b.upper_expr).evalf())
        th_lo = float(_sub_preview(th_b.lower_expr).evalf())
        th_hi = float(_sub_preview(th_b.upper_expr).evalf())
        rho_hi_fn = sp.lambdify((ph_sym, th_sym), _sub_preview(rho_b.upper_expr), modules=["numpy"])
        verts, proj = [], []
        grid = {}
        vc = 0
        for i, ph in enumerate(np.linspace(ph_lo, ph_hi, grid_res)):
            for j, th in enumerate(np.linspace(th_lo, th_hi, grid_res)):
                try:
                    rr = float(rho_hi_fn(ph, th))
                except Exception:
                    rr = 2.0
                px = rr * float(np.sin(ph) * np.cos(th))
                py = rr * float(np.sin(ph) * np.sin(th))
                pz = rr * float(np.cos(ph))
                verts.extend([round(px, 4), round(py, 4), round(pz, 4)])
                if i == grid_res // 2:
                    proj.extend([round(px, 4), round(py, 4), 0.0])
                grid[(i, j)] = vc
                vc += 1
        return {
            "type": "surface",
            "dimension": 3,
            "title": "Superficie Esférica V",
            "vertices": verts,
            "indices": Mesh3DGenerator._build_tri_indices(grid, grid_res, grid_res),
            "domain_projection": proj,
        }
