"""
Unit tests for Integra3D mathematical engine and OOP structures.
"""

import unittest
import sympy as sp
from app.domain.models import MultivariableIntegral, IntegrationBound, CoordinateSystem
from app.engine.solver import SymPyMultivariableSolver


class TestIntegra3DEngine(unittest.TestCase):

    def test_dunder_methods(self):
        b1 = IntegrationBound("y", "0", "1")
        b2 = IntegrationBound("x", "0", "2")
        integral = MultivariableIntegral("x * y", [b1, b2])

        # __len__
        self.assertEqual(len(integral), 2)
        # __getitem__
        self.assertEqual(integral[0].variable_str, "y")
        self.assertEqual(integral[1].variable_str, "x")
        # __call__ (numerical evaluation)
        self.assertEqual(integral(x=3, y=4), 12.0)
        # __str__ and __repr__
        self.assertIn("Integral_2", str(integral))
        self.assertIn("MultivariableIntegral", repr(integral))

    def test_double_integral_paraboloid(self):
        # Integral: z = 4 - x^2 - y^2 over circle r <= 2
        # Result should be exactly 8 * pi
        by = IntegrationBound("y", "-sqrt(4 - x**2)", "sqrt(4 - x**2)")
        bx = IntegrationBound("x", "-2", "2")
        integral = MultivariableIntegral("4 - x**2 - y**2", [by, bx])

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertIn("8 \\pi", solution.exact_latex)
        self.assertAlmostEqual(solution.approx_numeric, 25.132741, places=4)
        self.assertEqual(len(solution.steps), 5)

    def test_triple_integral_tetrahedron(self):
        # Fundamental tetrahedron x+y+z <= 1, x,y,z >= 0
        # Volume should be 1/6
        bz = IntegrationBound("z", "0", "1 - x - y")
        by = IntegrationBound("y", "0", "1 - x")
        bx = IntegrationBound("x", "0", "1")
        integral = MultivariableIntegral("1", [bz, by, bx])

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertEqual(solution.exact_latex, "\\frac{1}{6}")
        self.assertAlmostEqual(solution.approx_numeric, 0.166667, places=5)
        self.assertEqual(len(solution.steps), 7)

    def test_cylindrical_jacobian(self):
        # Cylinder of radius R=2 and height H=5
        # dV = r dz dr dtheta -> Volume = pi * R^2 * H = 20 * pi
        bz = IntegrationBound("z", "0", "5")
        br = IntegrationBound("r", "0", "2")
        bth = IntegrationBound("theta", "0", "2*pi")
        integral = MultivariableIntegral("1", [bz, br, bth], CoordinateSystem.CYLINDRICAL)

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertIn("20 \\pi", solution.exact_latex)
        self.assertAlmostEqual(solution.approx_numeric, 62.831853, places=4)

    def test_textbook_step_breakdown(self):
        # User image reference: \int_0^2 \int_0^x 4xy dy dx = 8
        by = IntegrationBound("y", "0", "x")
        bx = IntegrationBound("x", "0", "2")
        integral = MultivariableIntegral("4 * x * y", [by, bx])

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertEqual(solution.exact_latex, "8")
        self.assertIn("0 \\le x \\le 2", solution.region_definition)
        self.assertIn("0 \\le y \\le x", solution.region_definition)

        self.assertEqual(len(solution.steps), 5)

        # Steps 1-2: inner with respect to y (antiderivative + Barrow evaluation)
        step1 = solution.steps[0]
        self.assertEqual(step1.variable, "y")
        self.assertIn("Paso 1: Capa interna", step1.step_title)
        self.assertIn("2 x y^{2}", step1.antiderivative_latex)

        step2 = solution.steps[1]
        self.assertEqual(step2.variable, "y")
        self.assertIn("y = 0", step2.limits_evaluation_text)
        self.assertIn("y = x", step2.limits_evaluation_text)
        self.assertIn("2 x^{3}", step2.simplified_result_latex)

        # Steps 3-4: outer with respect to x (antiderivative + Barrow evaluation)
        step3 = solution.steps[2]
        self.assertEqual(step3.variable, "x")
        self.assertIn("Capa externa", step3.step_title)

        step4 = solution.steps[3]
        self.assertEqual(step4.variable, "x")
        self.assertEqual(step4.simplified_result_latex, "8")

        # Step 5: final synthesis
        step5 = solution.steps[4]
        self.assertEqual(step5.simplified_result_latex, "8")

    def test_llm_explainer_pedagogical_structure(self):
        from app.engine.llm_explainer import LLMExplainer
        by = IntegrationBound("y", "0", "x")
        bx = IntegrationBound("x", "0", "2")
        integral = MultivariableIntegral("4 * x * y", [by, bx])
        solution = SymPyMultivariableSolver.solve(integral)

        expl = LLMExplainer.generate_explanation(integral, solution)
        self.assertIn("region_definition", expl)
        self.assertIn("steps", expl)
        self.assertIn("sections", expl)
        self.assertEqual(len(expl["steps"]), 5)
        self.assertEqual(expl["exact_result_latex"], "8")
        self.assertEqual(expl["decimal_result"], 8.0)

    def test_limits_inversion_preserves_sign(self):
        # Integral from 9 to 4 of 2x dx: antiderivative is x^2, evaluated is 16 - 81 = -65
        bx = IntegrationBound("x", "9", "4")
        by = IntegrationBound("y", "0", "1")
        integral = MultivariableIntegral("2 * x", [bx, by])

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertEqual(solution.exact_latex, "-65")
        self.assertTrue(any(s.is_limit_inverted for s in solution.steps))
        self.assertTrue(any("Inversión de Límites" in s.applied_method for s in solution.steps))

    def test_order_reversal_y_cos_x3(self):
        # Classic textbook integral requiring order reversal:
        # \int_0^2 \int_{y/2}^1 y * cos(x^3) dx dy = 2/3 * sin(1) approx 0.56098
        bx = IntegrationBound("x", "y/2", "1")
        by = IntegrationBound("y", "0", "2")
        integral = MultivariableIntegral("y * cos(x**3)", [bx, by])

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertIn("\\sin", solution.exact_latex)
        self.assertAlmostEqual(solution.approx_numeric, 0.56098, places=4)
        self.assertGreaterEqual(len(solution.steps), 4)
        self.assertIn("orden de integración", solution.steps[0].step_title.lower())
        self.assertIsNotNone(solution.domain_analysis)

    def test_mat212_symbolic_constants_tetrahedron(self):
        bz = IntegrationBound("z", "0", "c*(1 - x/a - y/b)")
        by = IntegrationBound("y", "0", "b*(1 - x/a)")
        bx = IntegrationBound("x", "0", "a")
        integral = MultivariableIntegral("1", [bz, by, bx])

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertEqual(solution.exact_latex, "\\frac{a b c}{6}")

    def test_mat212_shifted_polar_circle(self):
        br = IntegrationBound("r", "0", "2*a*cos(theta)")
        bth = IntegrationBound("theta", "-pi/2", "pi/2")
        integral = MultivariableIntegral("r**2", [br, bth], CoordinateSystem.POLAR)

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertEqual(solution.exact_latex, "\\frac{3 \\pi a^{4}}{2}")
        self.assertEqual(solution.domain_analysis["region_type"], "Polar")
        self.assertIn("jacobian_latex", solution.domain_analysis)

    def test_mat212_order_reversal_sin_y_over_y(self):
        by = IntegrationBound("y", "x", "pi/2")
        bx = IntegrationBound("x", "0", "pi/2")
        integral = MultivariableIntegral("sin(y)/y", [by, bx])

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertEqual(solution.exact_latex, "1")
        self.assertAlmostEqual(solution.approx_numeric, 1.0, places=4)

    def test_mat212_uv_jacobian_4curves(self):
        by = IntegrationBound("y", "0", "1")
        bx = IntegrationBound("x", "0", "1")
        integral = MultivariableIntegral(
            "1",
            [by, bx],
            problem_mode="region_curves",
            boundary_curves=["x*y = 1", "x*y = 3", "y = x", "y = 3*x"],
        )

        solution = SymPyMultivariableSolver.solve(integral)
        self.assertTrue(solution.is_success)
        self.assertIn("\\log", solution.exact_latex)
        self.assertAlmostEqual(solution.approx_numeric, 1.098612, places=3)
        self.assertEqual(solution.domain_analysis["region_type"], "UV_Jacobian")

    def test_mat212_vertices_and_applications_and_mesh(self):
        from app.engine.mesh_generator import Mesh3DGenerator
        # Vertices A(0,0), B(10,1), C(1,1) -> area = 9/2 = 4.5
        by = IntegrationBound("y", "0", "1")
        bx = IntegrationBound("x", "0", "1")
        tri = MultivariableIntegral(
            "1",
            [by, bx],
            problem_mode="region_vertices",
            vertices_input="A(0,0), B(10,1), C(1,1)",
        )
        tri_sol = SymPyMultivariableSolver.solve(tri)
        self.assertTrue(tri_sol.is_success)
        self.assertAlmostEqual(tri_sol.approx_numeric, 4.5, places=4)
        self.assertEqual(tri_sol.domain_analysis["region_type"], "Type II")

        # Mesh with projection + dual surfaces
        vol = MultivariableIntegral(
            "1",
            [IntegrationBound("y", "x**2", "2*x"), IntegrationBound("x", "0", "2")],
            problem_mode="volume_between_surfaces",
            z_lower_expr="x**2 + y**2",
            z_upper_expr="8 - x**2 - y**2",
        )
        mesh = Mesh3DGenerator.generate_mesh(vol, grid_resolution=10)
        self.assertEqual(mesh["type"], "volume")
        self.assertIn("top_surface", mesh)
        self.assertIn("bottom_surface", mesh)
        self.assertTrue(len(mesh["domain_projection"]) > 0)

    def test_mat212_spherical_surface_area_and_mass(self):
        # 1. Surface area of plane z = 2*x + 3*y + 1 over [0, 2] x [0, 1] -> 2 * sqrt(14)
        surf = MultivariableIntegral(
            "1",
            [IntegrationBound("y", "0", "1"), IntegrationBound("x", "0", "2")],
            problem_mode="surface_area",
            z_upper_expr="2*x + 3*y + 1",
        )
        surf_sol = SymPyMultivariableSolver.solve(surf)
        self.assertTrue(surf_sol.is_success)
        self.assertAlmostEqual(surf_sol.approx_numeric, 2.0 * (14.0 ** 0.5), places=4)

        # 2. Mass & Center of Mass of cube [0, 2] x [0, 2] with density k -> M = 4k, centroid (1, 1)
        mass = MultivariableIntegral(
            "1",
            [IntegrationBound("y", "0", "2"), IntegrationBound("x", "0", "2")],
            problem_mode="mass_and_center_of_mass",
            density_expr="k",
        )
        mass_sol = SymPyMultivariableSolver.solve(mass)
        self.assertTrue(mass_sol.is_success)
        self.assertIsNotNone(mass_sol.application_summary)
        self.assertEqual(mass_sol.application_summary["mass_latex"], "4 k")
        self.assertEqual(mass_sol.application_summary["x_bar_latex"], "1")
        self.assertEqual(mass_sol.application_summary["y_bar_latex"], "1")

        # 3. Spherical Jacobian on unit rescaled ellipsoid (J_scale = 48 -> V = 64 pi)
        sph = MultivariableIntegral(
            "48",
            [
                IntegrationBound("rho", "0", "1"),
                IntegrationBound("phi", "0", "pi"),
                IntegrationBound("theta", "0", "2*pi"),
            ],
            CoordinateSystem.SPHERICAL,
        )
        sph_sol = SymPyMultivariableSolver.solve(sph)
        self.assertTrue(sph_sol.is_success)
        self.assertEqual(sph_sol.exact_latex, "64 \\pi")
        self.assertEqual(sph_sol.domain_analysis["region_type"], "Spherical")


if __name__ == "__main__":
    unittest.main()
