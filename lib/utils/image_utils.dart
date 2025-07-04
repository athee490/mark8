import 'package:image/image.dart' as img;
import 'dart:typed_data';

class ImageUtils {
  static List<float> imageToFloat32List(img.Image image, int inputWidth, int inputHeight) {
    final Float32List floatList = Float32List(inputWidth * inputHeight * 3);
    int index = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = image.getPixel(x, y);
        floatList[index++] = (img.getRed(pixel)) / 255.0;
        floatList[index++] = (img.getGreen(pixel)) / 255.0;
        floatList[index++] = (img.getBlue(pixel)) / 255.0;
      }
    }
    return floatList;
  }
}
