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
        self.assertEqual(len(solution.steps), 2)

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
        self.assertEqual(len(solution.steps), 3)

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


if __name__ == "__main__":
    unittest.main()
