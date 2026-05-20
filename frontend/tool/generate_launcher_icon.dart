import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

class Point {
  const Point(this.x, this.y);

  final double x;
  final double y;
}

void main() {
  const size = 1024;
  const logoWidth = 58.0;
  const logoHeight = 70.0;
  const logoPath =
      'M24.3987 69.3095C16.7571 69.3095 10.7529 67.0102 6.38624 62.4114C2.12875 57.7032 0 51.1883 0 42.8668C0 34.6548 1.74666 27.3187 5.23999 20.8586C8.73332 14.3984 13.5367 9.30696 19.65 5.58418C25.7633 1.86139 32.6954 0 40.4462 0C45.6862 0 49.8345 0.875953 52.8912 2.62785C55.9479 4.37975 57.4762 6.78861 57.4762 9.85443C57.4762 12.5918 56.1662 15.2744 53.5462 17.9022C52.5637 18.8877 51.2537 19.8184 49.6162 20.6943C48.0879 21.4608 46.887 21.844 46.0137 21.844C45.0312 21.844 44.2125 21.4608 43.5575 20.6943C42.4658 19.4899 41.0466 18.3402 39.3 17.2453C37.5533 16.1503 35.097 15.6029 31.9312 15.6029C26.5821 15.6029 22.2154 17.4642 18.8312 21.187C15.4471 24.8003 13.755 29.5633 13.755 35.476C13.755 40.8412 15.2833 45.1662 18.34 48.451C21.3966 51.7358 25.4358 53.3782 30.4575 53.3782C33.0775 53.3782 35.9158 52.9402 38.9725 52.0643C42.1383 51.0788 44.922 49.7102 47.3237 47.9583C48.5245 46.8633 49.7799 46.3158 51.0899 46.3158C53.2733 46.3158 54.3649 47.6845 54.3649 50.4219C54.3649 54.0352 52.5637 57.4842 48.9612 60.769C46.232 63.2874 42.575 65.3678 37.99 67.0102C33.5141 68.5431 28.9837 69.3095 24.3987 69.3095Z';

  final sourcePoints = _flattenPath(logoPath);
  final scale = size * 0.78 / logoHeight;
  final offsetX = (size - logoWidth * scale) / 2;
  final offsetY = (size - logoHeight * scale) / 2;
  final polygon = sourcePoints
      .map((p) => Point(offsetX + p.x * scale, offsetY + p.y * scale))
      .toList();

  final icon = img.Image(width: size, height: size);
  img.fill(icon, color: img.ColorRgb8(255, 255, 255));

  final green = img.ColorRgb8(36, 120, 109);
  for (var y = 0; y < size; y++) {
    final sampleY = y + 0.5;
    for (var x = 0; x < size; x++) {
      if (_containsPoint(polygon, x + 0.5, sampleY)) {
        icon.setPixel(x, y, green);
      }
    }
  }

  final output = File('assets/images/logo_launcher.png');
  output.writeAsBytesSync(img.encodePng(icon));
}

List<Point> _flattenPath(String path) {
  final tokens = RegExp(r'[MLCZ]|-?\d+(?:\.\d+)?').allMatches(path).map((m) {
    return m.group(0)!;
  }).toList();

  final points = <Point>[];
  var i = 0;
  var current = const Point(0, 0);
  var start = const Point(0, 0);
  String? command;

  double nextNumber() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    final token = tokens[i];
    if (RegExp(r'[MLCZ]').hasMatch(token)) {
      command = token;
      i++;
    }

    switch (command) {
      case 'M':
        current = Point(nextNumber(), nextNumber());
        start = current;
        points.add(current);
      case 'L':
        current = Point(nextNumber(), nextNumber());
        points.add(current);
      case 'C':
        final c1 = Point(nextNumber(), nextNumber());
        final c2 = Point(nextNumber(), nextNumber());
        final end = Point(nextNumber(), nextNumber());
        for (var step = 1; step <= 40; step++) {
          points.add(_cubicPoint(current, c1, c2, end, step / 40));
        }
        current = end;
      case 'Z':
        points.add(start);
        command = null;
      default:
        throw FormatException('Unsupported path command: $command');
    }
  }

  return points;
}

Point _cubicPoint(Point p0, Point p1, Point p2, Point p3, double t) {
  final u = 1 - t;
  return Point(
    math.pow(u, 3) * p0.x +
        3 * math.pow(u, 2) * t * p1.x +
        3 * u * math.pow(t, 2) * p2.x +
        math.pow(t, 3) * p3.x,
    math.pow(u, 3) * p0.y +
        3 * math.pow(u, 2) * t * p1.y +
        3 * u * math.pow(t, 2) * p2.y +
        math.pow(t, 3) * p3.y,
  );
}

bool _containsPoint(List<Point> polygon, double x, double y) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final pi = polygon[i];
    final pj = polygon[j];
    final intersects = (pi.y > y) != (pj.y > y) &&
        x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x;
    if (intersects) {
      inside = !inside;
    }
  }
  return inside;
}
