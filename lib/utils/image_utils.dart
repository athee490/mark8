import 'package:image/image.dart' as img;

class ImageUtils {
  static List<double> imageToFloat32List(img.Image image, int inputWidth, int inputHeight) {
    final resized = img.copyResize(image, width: inputWidth, height: inputHeight);
    final floatList = List<double>.filled(inputWidth * inputHeight * 3, 0);

    int index = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = resized.getPixel(x, y);
        floatList[index++] = pixel.r / 255.0; // Red
        floatList[index++] = pixel.g / 255.0; // Green
        floatList[index++] = pixel.b / 255.0; // Blue
      }
    }

    return floatList;
  }
}
