import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image/image.dart' show getRed, getGreen, getBlue;

class ImageUtils {
  static Float32List imageToFloat32List(
    img.Image image,
    int inputWidth,
    int inputHeight,
  ) {
    final convertedBytes = Float32List(1 * inputWidth * inputHeight * 3);
    final buffer = Float32List.view(convertedBytes.buffer);
    
    int pixelIndex = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = getRed(pixel) / 255.0;
        buffer[pixelIndex++] = getGreen(pixel) / 255.0;
        buffer[pixelIndex++] = getBlue(pixel) / 255.0;
      }
    }
    
    return convertedBytes;
  }
}