import 'package:image/image.dart' as img;

class ImageUtils {
  static List<double> imageToFloat32List(img.Image image, int inputWidth, int inputHeight) {
    final resized = img.copyResize(image, width: inputWidth, height: inputHeight);
    final floatList = List<double>.filled(inputWidth * inputHeight * 3, 0);

    int index = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = resized.getPixel(x, y);
        floatList[index++] = img.getRed(pixel) / 255.0;
        floatList[index++] = img.getGreen(pixel) / 255.0;
        floatList[index++] = img.getBlue(pixel) / 255.0;
      }
    }

    return floatList;
  }
}
