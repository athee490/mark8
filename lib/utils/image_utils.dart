import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageUtils {
  static Float32List imageToFloat32List(
    img.Image image,
    int inputWidth,
    int inputHeight,
  ) {
    print('[ImageUtils] imageToFloat32List called: inputWidth=[32m$inputWidth[0m, inputHeight=[32m$inputHeight[0m, image.size=${image.width}x${image.height}');
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
      if (y % 50 == 0) print('[ImageUtils] Processed row $y/$inputHeight');
    }
    print('[ImageUtils] imageToFloat32List finished: totalBytes=${convertedBytes.length}');
    return convertedBytes;
  }
}