import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  const cx = size ~/ 2;
  const cy = size ~/ 2;

  final image = img.Image(width: size, height: size);

  // Brand blue background
  img.fill(image, color: img.ColorRgb8(46, 134, 171));

  // White circle
  img.fillCircle(image, x: cx, y: cy, radius: 380, color: img.ColorRgb8(255, 255, 255));

  // Blue bowl body (bottom half ellipse)
  for (int y = cy - 80; y < cy + 280; y++) {
    for (int x = cx - 260; x <= cx + 260; x++) {
      final dx = x - cx, dy = y - cy;
      if ((dx * dx) / (260.0 * 260) + (dy * dy) / (260.0 * 260) <= 1.0) {
        image.setPixelRgb(x, y, 46, 134, 171);
      }
    }
  }

  // White bowl rim
  img.fillRect(image, x1: cx - 262, y1: cy - 100, x2: cx + 262, y2: cy - 68,
      color: img.ColorRgb8(255, 255, 255));

  // Steam — 3 white columns
  for (final ox in [-120, 0, 120]) {
    img.fillRect(image, x1: cx + ox - 22, y1: cy - 260, x2: cx + ox + 22, y2: cy - 120,
        color: img.ColorRgb8(255, 255, 255));
    img.fillCircle(image, x: cx + ox, y: cy - 260, radius: 22, color: img.ColorRgb8(255, 255, 255));
    img.fillCircle(image, x: cx + ox, y: cy - 120, radius: 22, color: img.ColorRgb8(255, 255, 255));
  }

  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(image));
  print('icon.png generated!');
}
