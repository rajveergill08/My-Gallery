import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:my_gallery/app.dart';
import 'package:my_gallery/providers/gallery_provider.dart';
import 'package:my_gallery/providers/settings_provider.dart';

void main() {
  testWidgets('shows splash branding', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => GalleryProvider(settings: settings),
          ),
        ],
        child: const MyGalleryApp(),
      ),
    );
    expect(find.text('MyGallery'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
