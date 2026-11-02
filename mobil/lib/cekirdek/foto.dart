import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Galeriden bir fotoğraf seçer; sunucunun 1 MB sınırına sığsın diye küçültülüp JPEG yapılır. Vazgeçilirse null.
/// Testlerde bu işlev değiştirilir.
Future<Uint8List?> Function() galeridenFotoSec = () async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
  return f?.readAsBytes();
};

/// Logo için: sıkıştırmadan (saydamlık korunur) yalnızca küçültülür. Vazgeçilirse null.
Future<Uint8List?> Function() galeridenLogoSec = () async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
  return f?.readAsBytes();
};
