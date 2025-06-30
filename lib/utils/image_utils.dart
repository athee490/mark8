import 'dart:typed_data';
import 'package:image/image.dart' as img;

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
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    
    return convertedBytes;
  }
}