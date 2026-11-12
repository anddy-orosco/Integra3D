import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../solver/presentation/widgets/latex_card.dart';

enum FormularyCategory {
  todos('Todos'),
  dobles('Integrales Dobles'),
  triples('Integrales Triples'),
  coordenadas('Coordenadas & Jacobiano'),
  vectorial('Teoremas Vectoriales'),
  metodos('Métodos & Sustitución'),
  inmediatas('Fórmulas Inmediatas');

  final String label;
  const FormularyCategory(this.label);
}

class FormularyItem {
  final String id;
  final FormularyCategory category;
  final String title;
  final String formulaLatex;
  final String description;
  final String application;
  final String? secondaryLatex;
  final List<String> tags;

  const FormularyItem({
    required this.id,
    required this.category,
    required this.title,
    required this.formulaLatex,
    required this.description,
    required this.application,
    this.secondaryLatex,
    required this.tags,
  });
}

class CalculusFormularyTab extends StatefulWidget {
  const CalculusFormularyTab({super.key});

  @override
  State<CalculusFormularyTab> createState() => _CalculusFormularyTabState();
}

class _CalculusFormularyTabState extends State<CalculusFormularyTab> {
  final TextEditingController _searchController = TextEditingController();
  FormularyCategory _selectedCategory = FormularyCategory.todos;
  String _searchQuery = '';

  static const List<FormularyItem> _items = [
    // 1. Integrales Dobles & Fubini
    FormularyItem(
      id: 'fubini_double',
      category: FormularyCategory.dobles,
      title: 'Teorema de Fubini para Integrales Dobles',
      formulaLatex: r'\iint_R f(x,y) \, dA = \int_a^b \left[ \int_{g_1(x)}^{g_2(x)} f(x,y) \, dy \right] dx = \int_c^d \left[ \int_{h_1(y)}^{h_2(y)} f(x,y) \, dx \right] dy',
      description: 'Establece que si una función f(x,y) es continua sobre una región acotada regular R en el plano ℝ², la integral doble se evalúa como dos integrales definidas simples consecutivas (integrales iteradas).',
      application: 'Permite reducir el cálculo de volúmenes o áreas en 2D a operaciones unidimensionales secuenciales manteniendo una variable constante.',
      tags: ['fubini', 'iterada', 'doble', 'orden', 'dx dy', 'dy dx', 'teorema'],
    ),
    FormularyItem(
      id: 'order_inversion',
      category: FormularyCategory.dobles,
      title: 'Inversión del Orden de Integración',
      formulaLatex: r'\int_c^d \int_{h_1(y)}^{h_2(y)} f(x,y) \, dx \, dy \Longleftrightarrow \int_a^b \int_{g_1(x)}^{g_2(x)} f(x,y) \, dy \, dx',
      description: 'Consiste en reinterpretar la región plana R desde el punto de vista del eje complementario (Tipo I vertical vs Tipo II horizontal), recalculando analíticamente los límites para despejar x o y.',
      application: 'Obligatorio cuando la antiderivada de la variable interna no es elemental (ej. ∫cos(x³) dx, ∫e^(-x²) dx, ∫(sin x)/x dx), permitiendo integrar primero respecto a la otra variable.',
      secondaryLatex: r'\text{Ejemplo: } \int_0^2 \int_{y/2}^1 y \cos(x^3) \, dx \, dy = \int_0^1 \int_0^{2x} y \cos(x^3) \, dy \, dx',
      tags: ['inversion', 'cambio de orden', 'orden', 'tipo 1', 'tipo 2', 'region', 'dydx', 'dxdy'],
    ),
    FormularyItem(
      id: 'area_mass_2d',
      category: FormularyCategory.dobles,
      title: 'Cálculo de Área y Masa en el Plano (2D)',
      formulaLatex: r'\text{Área}(R) = \iint_R 1 \, dA, \qquad M = \iint_R \rho(x,y) \, dA',
      description: 'El área de una región plana R corresponde a la integral de la función constante 1. Si la placa tiene una función de densidad superficial ρ(x,y), su integral sobre R proporciona la masa total M.',
      application: 'Modelado físico de placas delgadas, láminas con densidad variable y áreas bajo curvas paramétricas o implícitas.',
      tags: ['area', 'masa', 'densidad', 'plano', 'rho'],
    ),
    FormularyItem(
      id: 'center_mass_2d',
      category: FormularyCategory.dobles,
      title: 'Centro de Masa y Momentos de Inercia 2D',
      formulaLatex: r'\bar{x} = \frac{1}{M}\iint_R x\,\rho(x,y)\,dA, \quad \bar{y} = \frac{1}{M}\iint_R y\,\rho(x,y)\,dA, \quad I_0 = \iint_R (x^2+y^2)\,\rho\,dA',
      description: 'Coordenadas del baricentro (x̄, ȳ) ponderadas por la masa, junto con el momento polar de inercia I₀ con respecto al origen de coordenadas.',
      application: 'Cálculo estructural, estática, dinámica rotacional y equilibrio de cuerpos planos.',
      tags: ['centro de masa', 'inercia', 'baricentro', 'momentos'],
    ),

    // 2. Coordenadas y Jacobiano
    FormularyItem(
      id: 'jacobian_general',
      category: FormularyCategory.coordenadas,
      title: 'Teorema de Cambio de Variables y Jacobiano 2D',
      formulaLatex: r'\iint_R f(x,y) \, dx \, dy = \iint_S f(x(u,v), y(u,v)) \cdot |J(u,v)| \, du \, dv',
      description: 'Transforma una región irregular R en el plano xy a una región canónica S en el plano uv mediante una transformación biyectiva y diferenciable T(u,v) = (x(u,v), y(u,v)).',
      application: 'El determinante jacobiano cuantifica la deformación o factor de escala de áreas infinitesimales bajo la transformación de coordenadas.',
      secondaryLatex: r'J(u,v) = \frac{\partial(x,y)}{\partial(u,v)} = \det \begin{pmatrix} \frac{\partial x}{\partial u} & \frac{\partial x}{\partial v} \\ \frac{\partial y}{\partial u} & \frac{\partial y}{\partial v} \end{pmatrix} = \frac{\partial x}{\partial u}\frac{\partial y}{\partial v} - \frac{\partial x}{\partial v}\frac{\partial y}{\partial u}',
      tags: ['jacobiano', 'cambio de variables', 'matriz', 'determinante', 'uv'],
    ),
    FormularyItem(
      id: 'polar_coordinates',
      category: FormularyCategory.coordenadas,
      title: 'Coordenadas Polares en el Plano (Factor r)',
      formulaLatex: r'x = r\cos\theta, \quad y = r\sin\theta, \quad x^2 + y^2 = r^2 \implies dA = r \, dr \, d\theta',
      description: 'El factor de escala jacobiano en polares es |J| = r. Por ende, dx dy se reemplaza siempre por r dr dθ en toda integral doble.',
      application: 'Crucial para regiones con simetría circular (círculos, coronas circulares, cardioides) y funciones que dependen del radio r² = x² + y² (como exp(-(x²+y²))).',
      secondaryLatex: r'\iint_R f(x,y) \, dA = \int_{\alpha}^{\beta} \int_{r_1(\theta)}^{r_2(\theta)} f(r\cos\theta, r\sin\theta) \cdot r \, dr \, d\theta',
      tags: ['polares', 'r dr dtheta', 'theta', 'circulo', 'radial', 'jacobiano'],
    ),
    FormularyItem(
      id: 'cylindrical_coordinates',
      category: FormularyCategory.coordenadas,
      title: 'Coordenadas Cilíndricas en ℝ³ (Factor r)',
      formulaLatex: r'x = r\cos\theta, \quad y = r\sin\theta, \quad z = z \implies dV = r \, dz \, dr \, d\theta',
      description: 'Extensión natural de las coordenadas polares en el plano xy manteniendo el eje z cartesiano sin alterar. El jacobiano de volumen es |J| = r.',
      application: 'Ideal para sólidos con simetría axial alrededor del eje z: cilindros, paraboloides (z = x² + y² = r²), conos (z = r) y tuberías.',
      secondaryLatex: r'\iiint_E f(x,y,z) \, dV = \int_\alpha^\beta \int_{r_1}^{r_2} \int_{z_1(r,\theta)}^{z_2(r,\theta)} f(r\cos\theta, r\sin\theta, z) \cdot r \, dz \, dr \, d\theta',
      tags: ['cilindricas', 'cilindro', 'paraboloide', 'cono', 'r dz dr dtheta'],
    ),
    FormularyItem(
      id: 'spherical_coordinates',
      category: FormularyCategory.coordenadas,
      title: 'Coordenadas Esféricas en ℝ³ (Factor ρ² sin φ)',
      formulaLatex: r'x = \rho\sin\phi\cos\theta, \quad y = \rho\sin\phi\sin\theta, \quad z = \rho\cos\phi \implies dV = \rho^2 \sin\phi \, d\rho \, d\phi \, d\theta',
      description: 'Representa puntos mediante la distancia al origen ρ ≥ 0, el ángulo colatitud 0 ≤ φ ≤ π (desde el eje z positivo) y el ángulo acimutal 0 ≤ θ ≤ 2π (en el plano xy). El jacobiano es |J| = ρ² sin φ.',
      application: 'Indispensable para esferas, casquetes esféricos, conos y potenciales gravitatorios o electrostáticos con simetría central.',
      secondaryLatex: r'\rho^2 = x^2 + y^2 + z^2, \quad \iiint_E f \, dV = \int_0^{2\pi}\int_0^\pi\int_0^R f \cdot \rho^2 \sin\phi \, d\rho \, d\phi \, d\theta',
      tags: ['esfericas', 'esfera', 'rho', 'phi', 'theta', 'rho^2 sin phi'],
    ),

    // 3. Integrales Triples
    FormularyItem(
      id: 'triple_cartesian',
      category: FormularyCategory.triples,
      title: 'Integrales Triples en Coordenadas Cartesianas',
      formulaLatex: r'\iiint_E f(x,y,z) \, dV = \int_a^b \int_{g_1(x)}^{g_2(x)} \int_{u_1(x,y)}^{u_2(x,y)} f(x,y,z) \, dz \, dy \, dx',
      description: 'Evalúa la acumulación de una función tridimensional f sobre un dominio acotado E en ℝ³ acotado por superficies z = u₁(x,y) y z = u₂(x,y).',
      application: 'Cálculo de volumen de sólidos delimitados por planos, paraboloides e hiperboloides, así como masa total y centros de gravedad en 3D.',
      tags: ['triples', 'cartesianas', 'dz dy dx', 'volumen', 'espacio'],
    ),
    FormularyItem(
      id: 'volume_solids',
      category: FormularyCategory.triples,
      title: 'Cálculo de Volumen y Masa en ℝ³',
      formulaLatex: r'\text{Volumen}(E) = \iiint_E 1 \, dV, \qquad M = \iiint_E \rho(x,y,z) \, dV',
      description: 'El volumen tridimensional de cualquier sólido E equivale a integrar el elemento dV con integrando igual a 1. Si el sólido tiene densidad variable ρ, la integral da la masa física.',
      application: 'Geometría analítica, diseño mecánico y termodinámica de fluidos y sólidos continuos.',
      tags: ['volumen', 'masa', 'solido', 'rho'],
    ),

    // 4. Teoremas Vectoriales
    FormularyItem(
      id: 'green_theorem',
      category: FormularyCategory.vectorial,
      title: 'Teorema de Green en el Plano',
      formulaLatex: r'\oint_C (P \, dx + Q \, dy) = \iint_D \left( \frac{\partial Q}{\partial x} - \frac{\partial P}{\partial y} \right) dA',
      description: 'Relaciona la integral de línea de un campo vectorial a lo largo de una curva cerrada simple orientada positivamente (sentido antihorario) C con la integral doble sobre la región plana D que encierra.',
      application: 'Convierte integrales de línea complejas en integrales dobles sencillas y permite calcular el área de regiones poligonales o curvas cerradas.',
      secondaryLatex: r'\text{Área}(D) = \frac{1}{2} \oint_C (x \, dy - y \, dx) = \oint_C x \, dy = -\oint_C y \, dx',
      tags: ['green', 'curva cerrada', 'circulacion', 'rotacional 2d', 'teorema'],
    ),
    FormularyItem(
      id: 'divergence_gauss',
      category: FormularyCategory.vectorial,
      title: 'Teorema de la Divergencia de Gauss (Flujo 3D)',
      formulaLatex: r'\iint_{\partial E} \mathbf{F} \cdot \mathbf{n} \, dS = \iiint_E \nabla \cdot \mathbf{F} \, dV = \iiint_E \left( \frac{\partial P}{\partial x} + \frac{\partial Q}{\partial y} + \frac{\partial R}{\partial z} \right) dV',
      description: 'El flujo neto saliente de un campo vectorial F a través de una superficie cerrada orientada hacia afuera ∂E es idéntico a la integral de volumen de su divergencia sobre el interior del sólido E.',
      application: 'Pilar del electromagnetismo (Ley de Gauss), mecánica de fluidos incompresibles y conservación de la masa.',
      tags: ['gauss', 'divergencia', 'flujo', 'superficie cerrada', 'teorema'],
    ),
    FormularyItem(
      id: 'stokes_theorem',
      category: FormularyCategory.vectorial,
      title: 'Teorema de Stokes (Rotacional y Circulación)',
      formulaLatex: r'\oint_{\partial S} \mathbf{F} \cdot d\mathbf{r} = \iint_S (\nabla \times \mathbf{F}) \cdot \mathbf{n} \, dS',
      description: 'La circulación de un campo vectorial F a lo largo de la curva frontera orientada ∂S coincide con el flujo del rotacional de F a través de cualquier superficie orientada S que tenga a ∂S como borde.',
      application: 'Generalización tridimensional del Teorema de Green. Fundamental en inducción electromagnética (Ley de Faraday) y dinámica de vórtices.',
      tags: ['stokes', 'rotacional', 'circulacion', 'curl', 'ley de faraday'],
    ),
    FormularyItem(
      id: 'line_integral',
      category: FormularyCategory.vectorial,
      title: 'Integrales de Línea (Escalar y Vectorial)',
      formulaLatex: r"\int_C f \, ds = \int_a^b f(\mathbf{r}(t)) \|\mathbf{r}'(t)\| \, dt, \quad \int_C \mathbf{F} \cdot d\mathbf{r} = \int_a^b \mathbf{F}(\mathbf{r}(t)) \cdot \mathbf{r}'(t) \, dt",
      description: 'Cálculo de masa de alambres delgados con densidad f(x,y,z) y cálculo del trabajo mecánico W realizado por una fuerza vectorial F al mover una partícula a lo largo de la trayectoria C paramétrica r(t).',
      application: 'Física clásica, trabajo realizado por fuerzas no conservativas y potenciales electrostáticos.',
      tags: ['linea', 'curva', 'trabajo', 'ds', 'trayectoria'],
    ),
    FormularyItem(
      id: 'surface_integral',
      category: FormularyCategory.vectorial,
      title: 'Integral de Superficie Escalar y Flujo',
      formulaLatex: r'\iint_S f(x,y,z) \, dS = \iint_D f(x,y,g(x,y)) \sqrt{1 + \left(\frac{\partial g}{\partial x}\right)^2 + \left(\frac{\partial g}{\partial y}\right)^2} \, dA',
      description: 'Permite integrar una magnitud escalar o el producto punto con el vector normal unitario sobre una superficie curva z = g(x,y) proyectada en el plano D.',
      application: 'Cálculo de área de superficies curvas (cascarones, domos) y flujo de calor o fluidos.',
      tags: ['superficie', 'dS', 'area de superficie', 'normal'],
    ),

    // 5. Métodos y Técnicas de Integración
    FormularyItem(
      id: 'u_substitution',
      category: FormularyCategory.metodos,
      title: 'Método de Cambio de Variable (u-Sustitución)',
      formulaLatex: r"\int_a^b f(g(x)) g'(x) \, dx = \int_{g(a)}^{g(b)} f(u) \, du, \qquad u = g(x), \quad du = g'(x) \, dx",
      description: "Regla de la cadena invertida. Permite transformar un integrando complejo reconociendo la derivada interna g'(x) dx y actualizando directamente los límites de integración.",
      application: 'Técnica primaria en integrales iteradas tras integrar respecto a una variable y simplificar los términos algebraicos resultantes.',
      tags: ['sustitucion', 'u', 'cambio de variable', 'regla de la cadena', 'metodo'],
    ),
    FormularyItem(
      id: 'integration_by_parts',
      category: FormularyCategory.metodos,
      title: 'Integración por Partes',
      formulaLatex: r'\int_a^b u \, dv = [u \cdot v]_a^b - \int_a^b v \, du',
      description: 'Derivada del producto invertida. Se selecciona u según la jerarquía ILATE (Inversas, Logarítmicas, Algebraicas, Trigonométricas, Exponenciales) y dv el resto del diferencial.',
      application: 'Esencial cuando el integrando contiene productos de polinomios con exponenciales (x e^x) o polinomios con funciones trigonométricas (x sin x).',
      tags: ['partes', 'u dv', 'ilate', 'integral por partes'],
    ),
    FormularyItem(
      id: 'symmetry_properties',
      category: FormularyCategory.metodos,
      title: 'Propiedades de Simetría (Funciones Pares e Impares)',
      formulaLatex: r'\int_{-a}^a f_{\text{impar}}(x) \, dx = 0, \qquad \int_{-a}^a f_{\text{par}}(x) \, dx = 2 \int_0^a f_{\text{par}}(x) \, dx',
      description: 'Si una función satisface f(-x, y) = -f(x,y) sobre un intervalo simétrico [-a, a], el valor de la integral se anula de forma exacta sin necesidad de calcular la primitiva.',
      application: 'Ahorro sustancial en cálculos de integrales dobles y triples simétricas con respecto a planos coordenados.',
      tags: ['simetria', 'par', 'impar', 'anulacion', 'cero'],
    ),
    FormularyItem(
      id: 'barrow_rule',
      category: FormularyCategory.metodos,
      title: 'Regla de Barrow (Teorema Fundamental del Cálculo)',
      formulaLatex: r"\int_a^b f(x) \, dx = [F(x)]_a^b = F(b) - F(a), \quad \text{donde } F'(x) = f(x)",
      description: 'Conecta el concepto de derivada con el área bajo la curva: la integral definida se obtiene evaluando cualquier antiderivada F en el límite superior menos el límite inferior.',
      application: 'Paso obligatorio de evaluación en cada nivel de una integral iterada (interna, intermedia y externa).',
      tags: ['barrow', 'evaluacion', 'limites', 'antiderivada', 'tfc'],
    ),
    FormularyItem(
      id: 'limit_orientation_rule',
      category: FormularyCategory.metodos,
      title: 'Propiedad de Orientación e Inversión de Límites',
      formulaLatex: r'\int_a^b f(x) \, dx = - \int_b^a f(x) \, dx',
      description: 'Invertir el sentido de los límites de integración cambia el signo del resultado. Si el límite inferior es numéricamente mayor al superior, se añade un factor (-1) para respetar la orientación del espacio vectorial.',
      application: 'Garantiza consistencia física en integrales de flujo y cálculo de áreas con orientaciones dadas en curvas paramétricas.',
      tags: ['orientacion', 'inversion', 'signo', 'limites invertidos'],
    ),
    FormularyItem(
      id: 'trig_substitution',
      category: FormularyCategory.metodos,
      title: 'Sustituciones Trigonométricas para Radicales',
      formulaLatex: r'\sqrt{a^2 - x^2} \implies x = a\sin\theta, \quad \sqrt{a^2 + x^2} \implies x = a\tan\theta, \quad \sqrt{x^2 - a^2} \implies x = a\sec\theta',
      description: 'Elimina raíces cuadradas algebraicas de formas cuadráticas mediante las identidades pitagóricas 1 - sin²θ = cos²θ, 1 + tan²θ = sec²θ y sec²θ - 1 = tan²θ.',
      application: 'Frecuente en integrales con límites circulares como √(a² - x²), √(4 - x²), esferas y conos.',
      tags: ['trigonometrica', 'radicales', 'raiz', 'pitagorica', 'seno', 'tangente', 'secante'],
    ),

    // 6. Fórmulas Inmediatas y Clásicas
    FormularyItem(
      id: 'power_rule',
      category: FormularyCategory.inmediatas,
      title: 'Regla de la Potencia y Funciones Racionales',
      formulaLatex: r'\int x^n \, dx = \frac{x^{n+1}}{n+1} + C \quad (n \ne -1), \qquad \int \frac{1}{x} \, dx = \ln|x| + C',
      description: 'Fórmula básica fundamental de integración polinómica y regla del logaritmo natural para exponente singular n = -1.',
      application: 'Uso ubicuo en todo paso intermedio tras desarrollar integrales de monomios y polinomios.',
      tags: ['potencia', 'polinomio', 'logaritmo', 'inmediata'],
    ),
    FormularyItem(
      id: 'exponential_rule',
      category: FormularyCategory.inmediatas,
      title: 'Integrales de Exponenciales',
      formulaLatex: r'\int e^{kx} \, dx = \frac{1}{k}e^{kx} + C, \qquad \int a^x \, dx = \frac{a^x}{\ln a} + C',
      description: 'La función exponencial natural se reproduce a sí misma al derivarse o integrarse, escalada por el inverso de la constante interna k.',
      application: 'Común en modelos de difusión térmica, distribuciones gaussianas e integrales de Poisson.',
      tags: ['exponencial', 'e^x', 'inmediata'],
    ),
    FormularyItem(
      id: 'trig_integrals',
      category: FormularyCategory.inmediatas,
      title: 'Integrales Trigonométricas Inmediatas',
      formulaLatex: r'\int \cos(kx) \, dx = \frac{1}{k}\sin(kx) + C, \qquad \int \sin(kx) \, dx = -\frac{1}{k}\cos(kx) + C',
      description: 'Antiderivadas de las funciones periódicas fundamentales seno y coseno con factor de escala lineal k.',
      application: 'Aparece en coordenadas polares, armónicos cilíndricos y cambios de variables periódicos.',
      tags: ['seno', 'coseno', 'trigonometria', 'inmediata'],
    ),
    FormularyItem(
      id: 'inverse_trig_integrals',
      category: FormularyCategory.inmediatas,
      title: 'Integrales que Producen Funciones Trigonométricas Inversas',
      formulaLatex: r'\int \frac{1}{x^2 + a^2} \, dx = \frac{1}{a}\arctan\left(\frac{x}{a}\right) + C, \qquad \int \frac{1}{\sqrt{a^2 - x^2}} \, dx = \arcsin\left(\frac{x}{a}\right) + C',
      description: 'Primitivas indispensables que generan el arco tangente y el arco seno, fundamentales al integrar fracciones racionales y raíces de polinomios cuadráticos.',
      application: 'Resolución de integrales de Poisson, capacitancia electrostática y áreas de discos circulares.',
      tags: ['arctan', 'arcsin', 'arco tangente', 'arco seno', 'inmediata'],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FormularyItem> get _filteredItems {
    return _items.where((item) {
      final matchesCategory = _selectedCategory == FormularyCategory.todos ||
          item.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final inTitle = item.title.toLowerCase().contains(query);
      final inDesc = item.description.toLowerCase().contains(query);
      final inApp = item.application.toLowerCase().contains(query);
      final inTags = item.tags.any((t) => t.toLowerCase().contains(query));

      return inTitle || inDesc || inApp || inTags;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final filtered = _filteredItems;

    return Column(
      children: [
        // 1. Buscador y Filtro por Categorías
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: const BoxDecoration(
            color: AppColors.slateDark,
            border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de Búsqueda Interactiva
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(color: AppColors.pureWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar teorema, fórmula o método (ej. Fubini, Jacobiano, Polares)...',
                  hintStyle: const TextStyle(color: AppColors.mutedGray, fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.cyberEmerald, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.mutedGray),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.deepVoid,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.cyberEmerald, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Chips Horizontales de Categorías
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: FormularyCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.pureWhite : AppColors.mutedGray,
                          ),
                        ),
                        backgroundColor: AppColors.deepVoid,
                        selectedColor: AppColors.cyberEmerald.withAlpha(50),
                        checkmarkColor: AppColors.cyberEmerald,
                        side: BorderSide(
                          color: isSelected ? AppColors.cyberEmerald : AppColors.borderSubtle,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // 2. Lista de Tarjetas del Formulario
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 44, color: AppColors.mutedGray),
                      const SizedBox(height: 10),
                      Text(
                        'No se encontraron fórmulas para "$_searchQuery"',
                        style: const TextStyle(color: AppColors.mutedGray, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildFormularyCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFormularyCard(FormularyItem item) {
    Color badgeColor;
    switch (item.category) {
      case FormularyCategory.dobles:
        badgeColor = AppColors.electricCyan;
        break;
      case FormularyCategory.triples:
        badgeColor = AppColors.neonSky;
        break;
      case FormularyCategory.coordenadas:
        badgeColor = AppColors.cyberEmerald;
        break;
      case FormularyCategory.vectorial:
        badgeColor = AppColors.amberGlow;
        break;
      case FormularyCategory.metodos:
        badgeColor = AppColors.coralFlame;
        break;
      case FormularyCategory.inmediatas:
      default:
        badgeColor = AppColors.limePhosphor;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.slateDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de la Tarjeta con Categoría y Título
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.deepVoid.withAlpha(180),
                border: const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(35),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withAlpha(140)),
                    ),
                    child: Text(
                      item.category.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.pureWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tarjeta KaTeX Renderizada
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: LatexCard(
                latex: item.formulaLatex,
                isHighlight: true,
              ),
            ),

            // Ecuación secundaria o ejemplo si existe
            if (item.secondaryLatex != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: LatexCard(
                  latex: item.secondaryLatex!,
                  isHighlight: false,
                ),
              ),

            // Explicación Teórica y Uso
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.cyberEmerald),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.pureWhite,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.deepVoid.withAlpha(140),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderSubtle.withAlpha(120)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded, size: 13, color: AppColors.amberGlow),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '¿Cuándo se usa?: ${item.application}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedGray,
                              height: 1.35,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
