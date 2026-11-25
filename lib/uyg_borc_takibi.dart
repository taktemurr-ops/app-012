/// Borç Takibi · Debt Tracker
///
/// Borçlar, alacaklar ve ödemeler. Finans ve Hesaplama merkez uygulamasında yer alır; gerçek
/// uygulama ortak motordadır (finans_motoru), çatı studio_core/apps.
library;

import 'package:finans_motoru/finans_motoru.dart';
import 'package:studio_core/apps/apps.dart';

const String borcTakibiId = 'uyg-borc-takibi';

/// Merkezin kullandığı araç tanımı (33 dilde ad ve açıklama).
final AppTool borcTakibiTool = finansTool(borcTakibiId);
