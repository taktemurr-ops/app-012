import 'package:flutter_test/flutter_test.dart';
import 'package:uyg_borc_takibi/uyg_borc_takibi.dart';

void main() {
  test('33 dilde ad ve açıklama, doğru kimlik', () {
    expect(borcTakibiTool.id, borcTakibiId);
    expect(borcTakibiTool.title.length, 33);
    expect(borcTakibiTool.tagline.length, 33);
  });
}
