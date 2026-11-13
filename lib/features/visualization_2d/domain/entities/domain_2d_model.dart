import 'dart:ui';

enum SweepOrderType {
  typeI, // Vertical: dy dx
  typeII, // Horizontal: dx dy
}

class DomainPoint2D {
  final double x;
  final double y;
  final String label;

  const DomainPoint2D({
    required this.x,
    required this.y,
    required this.label,
  });
}

enum Curve2DKind {
  explicitYOfX,
  explicitXOfY,
  polarROfTheta,
  implicitFxy,
  segment,
}

class PlotCurve2D {
  final String label;
  final Curve2DKind kind;
  final Color color;
  final String? expression;
  final double? minParam;
  final double? maxParam;
  final Offset? segmentStart;
  final Offset? segmentEnd;
  final double Function(double t)? eval1D;
  final double Function(double x, double y)? evalImplicit;

  const PlotCurve2D({
    required this.label,
    required this.kind,
    required this.color,
    this.expression,
    this.minParam,
    this.maxParam,
    this.segmentStart,
    this.segmentEnd,
    this.eval1D,
    this.evalImplicit,
  });
}

class UvMappingModel {
  final String title;
  final String transformForwardLatex; // e.g. x = r\cos\theta, y = r\sin\theta
  final String transformInverseLatex; // e.g. u = xy, v = y/x
  final String jacobianLatex;
  final String uVarLabel;
  final String vVarLabel;
  final double uMin;
  final double uMax;
  final double vMin;
  final double vMax;
  final String uMinLatex;
  final String uMaxLatex;
  final String vMinLatex;
  final String vMaxLatex;
  final String transformedIntegralLatex;
  final bool isActiveTransformation;
  // Function mapping (u, v) -> (x, y) for grid distortion preview
  final Offset Function(double u, double v)? mapUvToXy;

  const UvMappingModel({
    required this.title,
    required this.transformForwardLatex,
    required this.transformInverseLatex,
    required this.jacobianLatex,
    this.uVarLabel = 'u',
    this.vVarLabel = 'v',
    required this.uMin,
    required this.uMax,
    required this.vMin,
    required this.vMax,
    required this.uMinLatex,
    required this.uMaxLatex,
    required this.vMinLatex,
    required this.vMaxLatex,
    required this.transformedIntegralLatex,
    this.isActiveTransformation = false,
    this.mapUvToXy,
  });
}

class Domain2DModel {
  final String title;
  final List<PlotCurve2D> curves;
  final List<List<Offset>> shadedRegions;
  final List<DomainPoint2D> intersectionPoints;
  final SweepOrderType preferredSweepOrder;

  // Type I (dy dx): x in [xMin, xMax], y in [yLower(x), yUpper(x)]
  final double xMin;
  final double xMax;
  final String xMinLatex;
  final String xMaxLatex;
  final String yLowerLatex;
  final String yUpperLatex;
  final double Function(double x)? yLowerAtX;
  final double Function(double x)? yUpperAtX;
  final String typeIIntegralLatex;

  // Type II (dx dy): y in [yMin, yMax], x in [xLower(y), xUpper(y)]
  final double yMin;
  final double yMax;
  final String yMinLatex;
  final String yMaxLatex;
  final String xLowerLatex;
  final String xUpperLatex;
  final double Function(double y)? xLowerAtY;
  final double Function(double y)? xUpperAtY;
  final String typeIIIntegralLatex;

  // Symbolic parameter display note (e.g. "Escala visual: a = 1, R = 2")
  final String? parameterNote;

  // UV / Polar mapping data
  final UvMappingModel? uvMapping;

  const Domain2DModel({
    required this.title,
    required this.curves,
    required this.shadedRegions,
    required this.intersectionPoints,
    required this.preferredSweepOrder,
    required this.xMin,
    required this.xMax,
    required this.xMinLatex,
    required this.xMaxLatex,
    required this.yLowerLatex,
    required this.yUpperLatex,
    this.yLowerAtX,
    this.yUpperAtX,
    required this.typeIIntegralLatex,
    required this.yMin,
    required this.yMax,
    required this.yMinLatex,
    required this.yMaxLatex,
    required this.xLowerLatex,
    required this.xUpperLatex,
    this.xLowerAtY,
    this.xUpperAtY,
    required this.typeIIIntegralLatex,
    this.parameterNote,
    this.uvMapping,
  });
}
