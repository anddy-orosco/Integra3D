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


if __name__ == "__main__":
    unittest.main()
