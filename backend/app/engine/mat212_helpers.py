"""
MAT 212 specialized region deduction, UV Jacobian transform, and physics/geometry application helpers
for the SymPy engine of Integra3D.
"""

import re
import time
from typing import Any, Dict, List, Optional, Tuple
import sympy as sp
from app.domain.models import (
    CoordinateSystem,
    IntegrationBound,
    MultivariableIntegral,
    parse_sympy_expr,
)


NON_ELEMENTARY_FUNCS = (
    sp.hyper,
    sp.Integral,
    sp.gamma,
    sp.lowergamma,
    sp.uppergamma,
    sp.Si,
    sp.Ci,
    sp.erf,
    sp.erfi,
    sp.fresnels,
    sp.fresnelc,
    sp.Ei,
    sp.li,
    sp.meijerg,
)


def has_non_elementary(expr: sp.Expr) -> bool:
    return any(expr.has(fn) for fn in NON_ELEMENTARY_FUNCS)


def build_domain_analysis(integral: MultivariableIntegral) -> Dict[str, Any]:
    """Builds structured `domain_analysis` metadata for 2D/3D/UV/Polar/Cylindrical/Spherical solutions."""
    coord = integral.coordinate_system
    vars_list = integral.variables
    region_type = "Type I"
    if coord == CoordinateSystem.POLAR:
        region_type = "Polar"
    elif coord == CoordinateSystem.CYLINDRICAL:
        region_type = "Cylindrical"
    elif coord == CoordinateSystem.SPHERICAL:
        region_type = "Spherical"
    elif integral.dimension >= 2 and vars_list[0] == "x" and vars_list[1] == "y":
        region_type = "Type II"

    intersections: List[Dict[str, str]] = []
    if integral.dimension >= 2 and coord == CoordinateSystem.CARTESIAN:
        b_in = integral.bounds[0]
        b_out = integral.bounds[1]
        v_in, v_out = b_in.variable_str, b_out.variable_str
        seen = set()
        for out_pt in (b_out.lower_expr, b_out.upper_expr):
            for in_expr in (b_in.lower_expr, b_in.upper_expr):
                try:
                    in_val = sp.simplify(in_expr.subs(b_out.var_sym, out_pt))
                    if v_in == "x":
                        px, py = sp.latex(in_val), sp.latex(out_pt)
                    else:
                        px, py = sp.latex(out_pt), sp.latex(in_val)
                    key = (px, py)
                    if key not in seen:
                        seen.add(key)
                        intersections.append({"x": px, "y": py})
                except Exception:
                    pass

    jac_latex: Optional[str] = None
    if coord == CoordinateSystem.POLAR:
        jac_latex = r"J = \frac{\partial(x,y)}{\partial(r,\theta)} = r"
    elif coord == CoordinateSystem.CYLINDRICAL:
        jac_latex = r"J = \frac{\partial(x,y,z)}{\partial(r,\theta,z)} = r"
    elif coord == CoordinateSystem.SPHERICAL:
        jac_latex = r"J = \frac{\partial(x,y,z)}{\partial(\rho,\phi,\theta)} = \rho^2 \sin\phi"

    parts = [f"{sp.latex(b.lower_expr)} \\le {b.variable_str} \\le {sp.latex(b.upper_expr)}" for b in reversed(integral.bounds)]
    return {
        "region_type": region_type,
        "intersection_points": intersections,
        "deduced_limits_latex": r", \quad ".join(parts),
        **({"jacobian_latex": jac_latex} if jac_latex else {}),
    }


def try_general_order_reversal(
    integral: MultivariableIntegral,
    solver_cls: Any,
    solver_step_cls: Any,
    solution_cls: Any,
    start_time: float,
) -> Optional[Any]:
    r"""
    Reverses a 2D iterated integral \int_{c}^{d} \int_{g1(v_out)}^{g2(v_out)} f dv_in dv_out
    into the opposite integration order across triangular, power, and trigonometric domains.
    """
    if integral.dimension != 2:
        return None
    b_in = integral.bounds[0]
    b_out = integral.bounds[1]
    v_in = b_in.var_sym
    v_out = b_out.var_sym
    out_lo, out_hi = b_out.lower_expr, b_out.upper_expr
    in_lo, in_hi = b_in.lower_expr, b_in.upper_expr

    if out_lo.free_symbols or out_hi.free_symbols:
        # Handle symbolic positive constants in outer bounds, only reject dependence on v_in
        if v_in in out_lo.free_symbols or v_in in out_hi.free_symbols:
            return None

    try:
        in_lo_has_out = v_out in in_lo.free_symbols
        in_hi_has_out = v_out in in_hi.free_symbols
        new_lower_in = None
        new_upper_in = None
        new_lower_out = None
        new_upper_out = None

        if in_lo_has_out and not in_hi_has_out:
            sols = sp.solve(sp.Eq(v_in, in_lo), v_out)
            if not sols:
                return None
            # Prefer real/positive solution consistent with out_lo..out_hi
            inv_expr = _pick_branch(sols, v_out, out_lo, out_hi, v_in, in_lo)
            v_at_lo = sp.simplify(in_lo.subs(v_out, out_lo))
            v_at_hi = sp.simplify(in_lo.subs(v_out, out_hi))
            c_const = sp.simplify(in_hi)
            if sp.simplify(v_at_hi - c_const) == 0:
                new_lower_out, new_upper_out = v_at_lo, c_const
                new_lower_in, new_upper_in = out_lo, inv_expr
            elif sp.simplify(v_at_lo - c_const) == 0:
                new_lower_out, new_upper_out = v_at_hi, c_const
                new_lower_in, new_upper_in = inv_expr, out_hi
            else:
                new_lower_out, new_upper_out = out_lo, c_const
                new_lower_in, new_upper_in = out_lo, inv_expr
        elif in_hi_has_out and not in_lo_has_out:
            sols = sp.solve(sp.Eq(v_in, in_hi), v_out)
            if not sols:
                return None
            inv_expr = _pick_branch(sols, v_out, out_lo, out_hi, v_in, in_hi)
            v_at_lo = sp.simplify(in_hi.subs(v_out, out_lo))
            v_at_hi = sp.simplify(in_hi.subs(v_out, out_hi))
            c_const = sp.simplify(in_lo)
            if sp.simplify(v_at_lo - c_const) == 0:
                new_lower_out, new_upper_out = c_const, v_at_hi
                new_lower_in, new_upper_in = inv_expr, out_hi
            else:
                new_lower_out, new_upper_out = c_const, v_at_lo
                new_lower_in, new_upper_in = out_lo, inv_expr
        else:
            return None

        expr = integral.effective_integrand()
        anti1 = sp.integrate(expr, v_out)
        if has_non_elementary(anti1):
            return None
        eval1 = sp.simplify(anti1.subs(v_out, new_upper_in) - anti1.subs(v_out, new_lower_in))
        if has_non_elementary(eval1):
            return None

        anti2 = sp.integrate(eval1, v_in)
        if has_non_elementary(anti2):
            return None
        eval2 = sp.simplify(anti2.subs(v_in, new_upper_out) - anti2.subs(v_in, new_lower_out))
        if has_non_elementary(eval2):
            return None

        approx_val = _try_evalf_real(eval2)
        exact_latex = sp.latex(eval2)

        steps = [
            solver_step_cls(
                step_number=1,
                variable=b_in.variable_str,
                lower_bound_latex=sp.latex(new_lower_out),
                upper_bound_latex=sp.latex(new_upper_out),
                current_integrand_latex=sp.latex(expr),
                step_title="Paso 1: Análisis de la región y cambio en el orden de integración",
                step_integral_latex=(
                    f"\\int_{{{sp.latex(out_lo)}}}^{{{sp.latex(out_hi)}}} "
                    f"\\int_{{{sp.latex(in_lo)}}}^{{{sp.latex(in_hi)}}} {sp.latex(expr)} \\, d{b_in.variable_str} \\, d{b_out.variable_str} = "
                    f"\\int_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} "
                    f"\\int_{{{sp.latex(new_lower_in)}}}^{{{sp.latex(new_upper_in)}}} {sp.latex(expr)} \\, d{b_out.variable_str} \\, d{b_in.variable_str}"
                ),
                constant_treatment_text=f"La antiderivada respecto a {b_in.variable_str} no es elemental. Por el Teorema de Fubini, invertimos el orden a d{b_out.variable_str} d{b_in.variable_str}:",
                antiderivative_work_latex=f"{sp.latex(new_lower_out)} \\le {b_in.variable_str} \\le {sp.latex(new_upper_out)}, \\quad {sp.latex(new_lower_in)} \\le {b_out.variable_str} \\le {sp.latex(new_upper_in)}",
                limits_evaluation_text=f"Despejando la frontera en el plano hacia d{b_out.variable_str} d{b_in.variable_str}:",
                antiderivative_latex=r"\text{Región con orden invertido}",
                evaluated_latex=(
                    f"\\int_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} "
                    f"\\int_{{{sp.latex(new_lower_in)}}}^{{{sp.latex(new_upper_in)}}} {sp.latex(expr)} \\, d{b_out.variable_str} \\, d{b_in.variable_str}"
                ),
                simplified_result_latex=(
                    f"\\int_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} "
                    f"\\int_{{{sp.latex(new_lower_in)}}}^{{{sp.latex(new_upper_in)}}} {sp.latex(expr)} \\, d{b_out.variable_str} \\, d{b_in.variable_str}"
                ),
                explanation=f"Invertimos los límites de integración proyectando primero respecto a {b_in.variable_str} ∈ [{sp.latex(new_lower_out)}, {sp.latex(new_upper_out)}] y luego {b_out.variable_str} ∈ [{sp.latex(new_lower_in)}, {sp.latex(new_upper_in)}].",
                applied_method="Teorema de Fubini (Cambio en el Orden de Integración)",
            ),
            solver_step_cls(
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
                explanation=f"La integración interna en {b_out.variable_str} cancela el denominador / genera el factor diferencial necesario.",
                applied_method="Integración Parcial tras Inversión de Orden",
            ),
            solver_step_cls(
                step_number=3,
                variable=b_in.variable_str,
                lower_bound_latex=sp.latex(new_lower_out),
                upper_bound_latex=sp.latex(new_upper_out),
                current_integrand_latex=sp.latex(eval1),
                step_title=f"Paso 3: Resolver la integral externa respecto a {b_in.variable_str}",
                step_integral_latex=f"\\int_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} {sp.latex(eval1)} \\, d{b_in.variable_str}",
                constant_treatment_text=f"Integramos la expresión resultante respecto a {b_in.variable_str}:",
                antiderivative_work_latex=f"\\int {sp.latex(eval1)} \\, d{b_in.variable_str} = {sp.latex(anti2)}",
                limits_evaluation_text=f"Evaluamos en los límites {b_in.variable_str} = {sp.latex(new_lower_out)} y {b_in.variable_str} = {sp.latex(new_upper_out)}:",
                antiderivative_latex=sp.latex(anti2),
                evaluated_latex=f"\\left[{sp.latex(anti2)}\\right]_{{{sp.latex(new_lower_out)}}}^{{{sp.latex(new_upper_out)}}} = {exact_latex}",
                simplified_result_latex=exact_latex,
                explanation="Aplicamos u-sustitución / reglas elementales y el Teorema Fundamental del Cálculo.",
                applied_method="Método de Sustitución & Teorema Fundamental del Cálculo",
            ),
            solver_step_cls(
                step_number=4,
                variable=b_in.variable_str,
                lower_bound_latex=sp.latex(new_lower_out),
                upper_bound_latex=sp.latex(new_upper_out),
                current_integrand_latex=exact_latex,
                step_title="Paso 4: Resultado final exacto",
                step_integral_latex=f"I = {exact_latex}",
                constant_treatment_text="Resultado analítico exacto:",
                antiderivative_work_latex=f"I = {exact_latex}" + (f" \\approx {approx_val:.5f}" if approx_val is not None else ""),
                limits_evaluation_text="Consolidación final:",
                antiderivative_latex=exact_latex,
                evaluated_latex=f"I = {exact_latex}",
                simplified_result_latex=exact_latex,
                explanation=f"El resultado exacto es {exact_latex}.",
                applied_method="Cálculo Multivariable Exacto",
            ),
        ]

        pts = []
        for out_end in (new_lower_out, new_upper_out):
            lo_e = sp.simplify(new_lower_in.subs(v_in, out_end))
            hi_e = sp.simplify(new_upper_in.subs(v_in, out_end))
            for cand in (lo_e, hi_e):
                entry = (
                    {"x": sp.latex(out_end), "y": sp.latex(cand)}
                    if b_in.variable_str == "x"
                    else {"x": sp.latex(cand), "y": sp.latex(out_end)}
                )
                if entry not in pts:
                    pts.append(entry)

        return solution_cls(
            is_success=True,
            exact_latex=exact_latex,
            approx_numeric=approx_val,
            steps=steps,
            original_integral_latex=integral.to_latex(),
            execution_time_ms=(time.perf_counter() - start_time) * 1000,
            region_definition=(
                f"Esta integral está definida sobre la región {sp.latex(new_lower_out)} \\le {b_in.variable_str} \\le {sp.latex(new_upper_out)} "
                f"y {sp.latex(new_lower_in)} \\le {b_out.variable_str} \\le {sp.latex(new_upper_in)}."
            ),
            domain_analysis={
                "region_type": "Type I" if b_out.variable_str == "y" else "Type II",
                "intersection_points": pts,
                "deduced_limits_latex": (
                    f"{sp.latex(new_lower_out)} \\le {b_in.variable_str} \\le {sp.latex(new_upper_out)}, \\quad "
                    f"{sp.latex(new_lower_in)} \\le {b_out.variable_str} \\le {sp.latex(new_upper_in)}"
                ),
            },
        )
    except Exception:
        return None


def _pick_branch(
    sols: List[sp.Expr],
    v_out: sp.Symbol,
    out_lo: sp.Expr,
    out_hi: sp.Expr,
    v_in: sp.Symbol,
    original_expr: sp.Expr,
) -> sp.Expr:
    if len(sols) == 1:
        return sols[0]
    try:
        mid_out = (out_lo + out_hi) / 2
        val_in = original_expr.subs(v_out, mid_out)
        mid_val_f = float(mid_out.evalf())
        best = sols[-1]
        best_dist = float("inf")
        for cand in sols:
            c_val = complex(cand.subs(v_in, val_in).evalf())
            if abs(c_val.imag) < 1e-8:
                dist = abs(c_val.real - mid_val_f)
                if dist < best_dist:
                    best_dist = dist
                    best = cand
        return best
    except Exception:
        return sols[-1]


def _try_evalf_real(expr: sp.Expr) -> Optional[float]:
    try:
        if expr.free_symbols:
            return None
        val = complex(expr.evalf())
        if abs(val.imag) < 1e-10:
            return round(float(val.real), 6)
    except Exception:
        pass
    return None


def solve_mat212_mode(
    integral: MultivariableIntegral,
    solver_cls: Any,
    solver_step_cls: Any,
    solution_cls: Any,
    start_time: float,
) -> Optional[Any]:
    """Handles specialized MAT 212 modes (region_vertices, region_curves, surface_area, volume_between_surfaces, mass_and_center_of_mass, planar_area)."""
    mode = integral.problem_mode
    if mode == "planar_area":
        area_int = MultivariableIntegral(
            integrand="1",
            bounds=integral.bounds,
            coordinate_system=integral.coordinate_system,
            problem_mode="region_curves" if integral.boundary_curves else ("region_vertices" if integral.vertices_input else "direct"),
            boundary_curves=integral.boundary_curves,
            vertices_input=integral.vertices_input,
        )
        return solver_cls.solve(area_int)

    if mode == "volume_between_surfaces":
        z_sup = integral.z_upper_expr or integral.integrand_str or "1"
        z_inf = integral.z_lower_expr or "0"
        vol_int = MultivariableIntegral(
            integrand=f"({z_sup}) - ({z_inf})",
            bounds=integral.bounds,
            coordinate_system=integral.coordinate_system,
            problem_mode="region_curves" if integral.boundary_curves else "direct",
            boundary_curves=integral.boundary_curves,
        )
        return solver_cls.solve(vol_int)

    if mode == "surface_area":
        z_str = integral.z_upper_expr or integral.integrand_str
        z_expr = parse_sympy_expr(z_str)
        x_sym, y_sym = sp.Symbol("x"), sp.Symbol("y")
        dz_dx = sp.diff(z_expr, x_sym)
        dz_dy = sp.diff(z_expr, y_sym)
        ds_expr = sp.simplify(sp.sqrt(1 + dz_dx**2 + dz_dy**2))
        if integral.coordinate_system == CoordinateSystem.POLAR:
            r_sym, th_sym = sp.Symbol("r"), sp.Symbol("theta")
            ds_expr = sp.simplify(ds_expr.subs({x_sym: r_sym * sp.cos(th_sym), y_sym: r_sym * sp.sin(th_sym)}))
        surf_int = MultivariableIntegral(
            integrand=str(ds_expr),
            bounds=integral.bounds,
            coordinate_system=integral.coordinate_system,
        )
        return solver_cls.solve(surf_int)

    if mode == "mass_and_center_of_mass":
        return _solve_mass_centroid(integral, solver_cls, solver_step_cls, solution_cls, start_time)

    if mode == "region_vertices" and integral.vertices_input:
        return _solve_region_vertices(integral, solver_cls, solver_step_cls, solution_cls, start_time)

    if mode == "region_curves" and integral.boundary_curves:
        return _solve_region_curves(integral, solver_cls, solver_step_cls, solution_cls, start_time)

    return None


def _solve_mass_centroid(
    integral: MultivariableIntegral,
    solver_cls: Any,
    solver_step_cls: Any,
    solution_cls: Any,
    start_time: float,
) -> Optional[Any]:
    rho_str = integral.density_expr or integral.integrand_str or "1"
    rho_expr = parse_sympy_expr(rho_str)
    is_3d = integral.dimension == 3
    coord = integral.coordinate_system

    if coord in (CoordinateSystem.POLAR, CoordinateSystem.CYLINDRICAL):
        r_sym, th_sym = sp.Symbol("r"), sp.Symbol("theta")
        x_map = r_sym * sp.cos(th_sym)
        y_map = r_sym * sp.sin(th_sym)
        z_map = sp.Symbol("z")
        rho_c = sp.simplify(rho_expr.subs({sp.Symbol("x"): x_map, sp.Symbol("y"): y_map}))
    elif coord == CoordinateSystem.SPHERICAL:
        rh_sym, ph_sym, th_sym = sp.Symbol("rho"), sp.Symbol("phi"), sp.Symbol("theta")
        x_map = rh_sym * sp.sin(ph_sym) * sp.cos(th_sym)
        y_map = rh_sym * sp.sin(ph_sym) * sp.sin(th_sym)
        z_map = rh_sym * sp.cos(ph_sym)
        rho_c = sp.simplify(rho_expr.subs({sp.Symbol("x"): x_map, sp.Symbol("y"): y_map, sp.Symbol("z"): z_map}))
    else:
        x_map, y_map, z_map = sp.Symbol("x"), sp.Symbol("y"), sp.Symbol("z")
        rho_c = rho_expr

    def _run(expr: sp.Expr) -> Any:
        return solver_cls.solve(MultivariableIntegral(str(expr), integral.bounds, coord))

    m_sol = _run(rho_c)
    myz_sol = _run(rho_c * x_map)
    mxz_sol = _run(rho_c * y_map)
    mxy_sol = _run(rho_c * z_map) if is_3d else None

    if not m_sol.is_success:
        return m_sol

    m_sym = sp.simplify(
        parse_from_solution_bounds(rho_c * integral.jacobian_factor(), integral.bounds)
    )
    myz_sym = sp.simplify(parse_from_solution_bounds(rho_c * x_map * integral.jacobian_factor(), integral.bounds))
    mxz_sym = sp.simplify(parse_from_solution_bounds(rho_c * y_map * integral.jacobian_factor(), integral.bounds))
    x_bar = sp.simplify(myz_sym / m_sym) if m_sym != 0 else sp.Integer(0)
    y_bar = sp.simplify(mxz_sym / m_sym) if m_sym != 0 else sp.Integer(0)
    summary: Dict[str, Any] = {
        "mass_latex": m_sol.exact_latex,
        "myz_latex": myz_sol.exact_latex,
        "mxz_latex": mxz_sol.exact_latex,
        "x_bar_latex": sp.latex(x_bar),
        "y_bar_latex": sp.latex(y_bar),
    }
    if is_3d and mxy_sol is not None:
        mxy_sym = sp.simplify(parse_from_solution_bounds(rho_c * z_map * integral.jacobian_factor(), integral.bounds))
        z_bar = sp.simplify(mxy_sym / m_sym) if m_sym != 0 else sp.Integer(0)
        summary["mxy_latex"] = mxy_sol.exact_latex
        summary["z_bar_latex"] = sp.latex(z_bar)
        centroid_ltx = f"(\\bar{{x}}, \\bar{{y}}, \\bar{{z}}) = \\left({sp.latex(x_bar)},\\; {sp.latex(y_bar)},\\; {sp.latex(z_bar)}\\right)"
    else:
        centroid_ltx = f"(\\bar{{x}}, \\bar{{y}}) = \\left({sp.latex(x_bar)},\\; {sp.latex(y_bar)}\\right)"

    return solution_cls(
        is_success=True,
        exact_latex=f"M = {m_sol.exact_latex},\\; {centroid_ltx}",
        approx_numeric=m_sol.approx_numeric,
        steps=m_sol.steps,
        original_integral_latex=m_sol.original_integral_latex,
        execution_time_ms=(time.perf_counter() - start_time) * 1000,
        region_definition=m_sol.region_definition,
        formulas_and_methods=m_sol.formulas_and_methods,
        domain_analysis=m_sol.domain_analysis,
        application_summary=summary,
    )


def parse_from_solution_bounds(expr: sp.Expr, bounds: List[IntegrationBound]) -> sp.Expr:
    cur = expr
    for b in bounds:
        cur = sp.integrate(cur, (b.var_sym, b.lower_expr, b.upper_expr))
    return sp.simplify(cur)


def _solve_region_vertices(
    integral: MultivariableIntegral,
    solver_cls: Any,
    solver_step_cls: Any,
    solution_cls: Any,
    start_time: float,
) -> Optional[Any]:
    matches = re.findall(r"[A-Za-z]?\s*\(\s*([^,()]+)\s*,\s*([^,()]+)\s*\)", integral.vertices_input or "")
    if len(matches) < 3:
        return None
    pts = [(float(parse_sympy_expr(mx).evalf()), float(parse_sympy_expr(my).evalf())) for mx, my in matches]
    # Triangle fast path with shared horizontal or vertical edge
    if len(pts) == 3:
        y_vals = sorted({round(p[1], 6) for p in pts})
        if len(y_vals) == 2:
            # Two vertices share y -> horizontal Type II single integral!
            y_lo, y_hi = y_vals[0], y_vals[1]
            # Sort left/right slopes from single vertex to the two vertices on opposite y
            apex = [p for p in pts if round(p[1], 6) == (y_lo if sum(round(p[1], 6) == y_lo for p in pts) == 1 else y_hi)][0]
            base = [p for p in pts if p != apex]
            base.sort(key=lambda p: p[0])
            def _line_x(p1: Tuple[float, float], p2: Tuple[float, float]) -> sp.Expr:
                y_sym = sp.Symbol("y")
                if abs(p2[1] - p1[1]) < 1e-9:
                    return sp.nsimplify(p1[0])
                slope = sp.nsimplify((p2[0] - p1[0]) / (p2[1] - p1[1]))
                return sp.simplify(sp.nsimplify(p1[0]) + slope * (y_sym - sp.nsimplify(p1[1])))
            x_l = _line_x(apex, base[0])
            x_r = _line_x(apex, base[1])
            sub = MultivariableIntegral(
                integrand=integral.integrand_str,
                bounds=[
                    IntegrationBound("x", str(x_l), str(x_r)),
                    IntegrationBound("y", str(sp.nsimplify(y_lo)), str(sp.nsimplify(y_hi))),
                ],
            )
            sol = solver_cls.solve(sub)
            step0 = solver_step_cls(
                step_number=0,
                variable="x",
                lower_bound_latex=sp.latex(x_l),
                upper_bound_latex=sp.latex(x_r),
                current_integrand_latex=sp.latex(integral.integrand_expr),
                antiderivative_latex=sub.to_latex(),
                evaluated_latex=sub.to_latex(),
                simplified_result_latex=sub.to_latex(),
                explanation="Deducimos los lados rectos del polígono y elegimos barrido Tipo II (dx dy) para evaluar en una sola integral iterada.",
                applied_method="Deducción Geométrica de Límites de Dominio",
                step_title="Paso 0: Deducción Geométrica de los Límites de Integración",
                step_integral_latex=sub.to_latex(),
            )
            sol.steps = [step0] + sol.steps
            sol.domain_analysis = {
                "region_type": "Type II",
                "intersection_points": [{"x": sp.latex(sp.nsimplify(p[0])), "y": sp.latex(sp.nsimplify(p[1]))} for p in pts],
                "deduced_limits_latex": f"{sp.latex(sp.nsimplify(y_lo))} \\le y \\le {sp.latex(sp.nsimplify(y_hi))}, \\quad {sp.latex(x_l)} \\le x \\le {sp.latex(x_r)}",
            }
            return sol
    return None


def _solve_region_curves(
    integral: MultivariableIntegral,
    solver_cls: Any,
    solver_step_cls: Any,
    solution_cls: Any,
    start_time: float,
) -> Optional[Any]:
    curves = [c.strip() for c in integral.boundary_curves if "=" in c]
    x_sym, y_sym = sp.Symbol("x"), sp.Symbol("y")
    u_sym, v_sym = sp.Symbol("u"), sp.Symbol("v")

    # 1. Detect 4-curve UV families (e.g. x*y=1, x*y=3, y=x, y=3*x or x+y=1, x+y=3, x-2y=0, x-2y=4)
    if len(curves) == 4:
        uv_res = _try_uv_4curve_family(curves, integral, solver_step_cls, solution_cls, start_time)
        if uv_res is not None:
            return uv_res

    # 2. Detect two curves defining Type I region (e.g. y = 2*x, y = x^2)
    if len(curves) == 2:
        try:
            ys = []
            for c in curves:
                lhs, rhs = c.split("=", 1)
                lhs_e, rhs_e = parse_sympy_expr(lhs), parse_sympy_expr(rhs)
                sols = sp.solve(sp.Eq(lhs_e, rhs_e), y_sym)
                if not sols:
                    break
                ys.append(sols[0])
            if len(ys) == 2:
                inter_x = [r for r in sp.solve(sp.Eq(ys[0], ys[1]), x_sym) if not r.has(sp.I)]
                if len(inter_x) >= 2:
                    inter_x.sort(key=lambda r: float(r.evalf()))
                    x0, x1 = inter_x[0], inter_x[-1]
                    mid_x = (x0 + x1) / 2
                    if float((ys[1] - ys[0]).subs(x_sym, mid_x).evalf()) < 0:
                        y_low, y_upp = ys[1], ys[0]
                    else:
                        y_low, y_upp = ys[0], ys[1]
                    compiled = MultivariableIntegral(
                        integrand=integral.integrand_str,
                        bounds=[
                            IntegrationBound("y", str(y_low), str(y_upp)),
                            IntegrationBound("x", str(x0), str(x1)),
                        ],
                    )
                    sol = solver_cls.solve(compiled)
                    pts = [{"x": sp.latex(ix), "y": sp.latex(sp.simplify(y_low.subs(x_sym, ix)))} for ix in (x0, x1)]
                    step0 = solver_step_cls(
                        step_number=0,
                        variable="y",
                        lower_bound_latex=sp.latex(y_low),
                        upper_bound_latex=sp.latex(y_upp),
                        current_integrand_latex=sp.latex(integral.integrand_expr),
                        antiderivative_latex=compiled.to_latex(),
                        evaluated_latex=compiled.to_latex(),
                        simplified_result_latex=compiled.to_latex(),
                        explanation=f"Igualando las curvas frontera encontramos los cortes x ∈ [{sp.latex(x0)}, {sp.latex(x1)}].",
                        applied_method="Deducción Geométrica de Límites de Dominio",
                        step_title="Paso 0: Deducción Geométrica de los Límites de Integración",
                        step_integral_latex=compiled.to_latex(),
                    )
                    sol.steps = [step0] + sol.steps
                    sol.domain_analysis = {
                        "region_type": "Type I",
                        "intersection_points": pts,
                        "deduced_limits_latex": compiled.to_latex(),
                    }
                    return sol
        except Exception:
            pass
    return None


def _try_uv_4curve_family(
    curves: List[str],
    integral: MultivariableIntegral,
    solver_step_cls: Any,
    solution_cls: Any,
    start_time: float,
) -> Optional[Any]:
    x_sym, y_sym = sp.Symbol("x"), sp.Symbol("y")
    u_sym, v_sym = sp.Symbol("u"), sp.Symbol("v")
    pairs: List[Tuple[sp.Expr, float]] = []
    try:
        for c in curves:
            lhs_s, rhs_s = c.split("=", 1)
            lhs_e, rhs_e = parse_sympy_expr(lhs_s), parse_sympy_expr(rhs_s)
            diff_e = sp.simplify(lhs_e - rhs_e)
            # Check constant term separation: f(x,y) = k
            const = diff_e.subs({x_sym: 0, y_sym: 0})
            if const != 0 and diff_e.is_Add:
                expr_part = sp.simplify(diff_e - const)
                pairs.append((expr_part, float((-const).evalf())))
            else:
                # Quotient curve like y - k*x = 0 -> y/x = k
                sol_yx = sp.solve(diff_e, y_sym)
                if sol_yx:
                    ratio = sp.simplify(sol_yx[0] / x_sym)
                    if ratio.is_Number:
                        pairs.append((y_sym / x_sym, float(ratio.evalf())))
                        continue
                return None

        # Group by matching base expression string
        groups: Dict[str, Tuple[sp.Expr, List[float]]] = {}
        for expr_part, k_val in pairs:
            key = str(sp.simplify(expr_part))
            if key not in groups:
                groups[key] = (expr_part, [k_val])
            else:
                groups[key][1].append(k_val)

        if len(groups) != 2 or any(len(v[1]) != 2 for v in groups.values()):
            return None

        grp_list = list(groups.values())
        u_expr, u_vals = grp_list[0][0], sorted(grp_list[0][1])
        v_expr, v_vals = grp_list[1][0], sorted(grp_list[1][1])

        u1, u2 = sp.nsimplify(u_vals[0]), sp.nsimplify(u_vals[1])
        v1, v2 = sp.nsimplify(v_vals[0]), sp.nsimplify(v_vals[1])

        # Jacobian d(u,v)/d(x,y)
        du_dx, du_dy = sp.diff(u_expr, x_sym), sp.diff(u_expr, y_sym)
        dv_dx, dv_dy = sp.diff(v_expr, x_sym), sp.diff(v_expr, y_sym)
        det_uv_xy = sp.simplify(du_dx * dv_dy - du_dy * dv_dx)

        # Solve x(u,v), y(u,v) for positive quadrant
        inv_sols = sp.solve([sp.Eq(u_expr, u_sym), sp.Eq(v_expr, v_sym)], (x_sym, y_sym))
        if not inv_sols:
            return None
        if isinstance(inv_sols, dict):
            x_uv, y_uv = inv_sols[x_sym], inv_sols[y_sym]
        else:
            x_uv, y_uv = inv_sols[-1]

        j_inv_in_uv = sp.simplify(det_uv_xy.subs({x_sym: x_uv, y_sym: y_uv}))
        jac_uv = sp.simplify(1 / abs(j_inv_in_uv)) if j_inv_in_uv.is_Number else sp.simplify(
            sp.diff(x_uv, u_sym) * sp.diff(y_uv, v_sym) - sp.diff(x_uv, v_sym) * sp.diff(y_uv, u_sym)
        )
        # Ensure positive Jacobian magnitude over u1..u2, v1..v2
        mid_u = float(((u1 + u2) / 2).evalf())
        mid_v = float(((v1 + v2) / 2).evalf())
        j_sign_sample = float(jac_uv.subs({u_sym: mid_u, v_sym: mid_v}).evalf())
        abs_j = sp.simplify(-jac_uv if j_sign_sample < 0 else jac_uv)

        f_uv = sp.simplify(integral.integrand_expr.subs({x_sym: x_uv, y_sym: y_uv}) * abs_j)
        eval1 = sp.integrate(f_uv, (u_sym, u1, u2))
        eval2 = sp.simplify(sp.integrate(eval1, (v_sym, v1, v2)))
        exact_latex = sp.latex(eval2)
        approx_val = _try_evalf_real(eval2)
        jac_latex = f"J = \\left|\\frac{{\\partial(x,y)}}{{\\partial(u,v)}}\\right| = {sp.latex(abs_j)}"

        steps = [
            solver_step_cls(
                step_number=1,
                variable="u",
                lower_bound_latex=sp.latex(u1),
                upper_bound_latex=sp.latex(u2),
                current_integrand_latex=sp.latex(integral.integrand_expr),
                antiderivative_latex=jac_latex,
                evaluated_latex=jac_latex,
                simplified_result_latex=jac_latex,
                explanation=f"Definimos u = {sp.latex(u_expr)} ∈ [{sp.latex(u1)}, {sp.latex(u2)}] y v = {sp.latex(v_expr)} ∈ [{sp.latex(v1)}, {sp.latex(v2)}], obteniendo el Jacobiano inverso.",
                applied_method="Transformación General (u, v) y Determinante Jacobiano",
                step_title="Paso 1: Definición de u, v y cálculo del Determinante Jacobiano",
                step_integral_latex=f"u = {sp.latex(u_expr)}, \\quad v = {sp.latex(v_expr)}, \\quad {jac_latex}",
            ),
            solver_step_cls(
                step_number=2,
                variable="v",
                lower_bound_latex=sp.latex(v1),
                upper_bound_latex=sp.latex(v2),
                current_integrand_latex=sp.latex(f_uv),
                antiderivative_latex=exact_latex,
                evaluated_latex=f"\\int_{{{sp.latex(v1)}}}^{{{sp.latex(v2)}}} \\int_{{{sp.latex(u1)}}}^{{{sp.latex(u2)}}} {sp.latex(f_uv)} \\, du \\, dv = {exact_latex}",
                simplified_result_latex=exact_latex,
                explanation="Integramos la función transformada sobre el rectángulo simple en el plano UV.",
                applied_method="Evaluación en el Plano UV",
                step_title="Paso 2: Integración sobre el rectángulo UV",
                step_integral_latex=f"\\int_{{{sp.latex(v1)}}}^{{{sp.latex(v2)}}} \\int_{{{sp.latex(u1)}}}^{{{sp.latex(u2)}}} {sp.latex(f_uv)} \\, du \\, dv",
            ),
        ]

        return solution_cls(
            is_success=True,
            exact_latex=exact_latex,
            approx_numeric=approx_val,
            steps=steps,
            original_integral_latex=f"\\iint_R {sp.latex(integral.integrand_expr)} \\, dA",
            execution_time_ms=(time.perf_counter() - start_time) * 1000,
            region_definition=f"Región curvilínea transformada al rectángulo u ∈ [{sp.latex(u1)}, {sp.latex(u2)}], v ∈ [{sp.latex(v1)}, {sp.latex(v2)}].",
            domain_analysis={
                "region_type": "UV_Jacobian",
                "intersection_points": [
                    {"x": f"u={sp.latex(u1)}", "y": f"v={sp.latex(v1)}"},
                    {"x": f"u={sp.latex(u2)}", "y": f"v={sp.latex(v2)}"},
                ],
                "deduced_limits_latex": f"{sp.latex(u1)} \\le u \\le {sp.latex(u2)}, \\quad {sp.latex(v1)} \\le v \\le {sp.latex(v2)}",
                "jacobian_latex": jac_latex,
                "uv_bounds": {"u_min": float(u1.evalf()), "u_max": float(u2.evalf()), "v_min": float(v1.evalf()), "v_max": float(v2.evalf())},
            },
        )
    except Exception:
        return None
