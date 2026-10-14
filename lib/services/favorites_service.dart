import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favourite_asset_ids';

  Future<Set<String>> load() async =>
      ((await SharedPreferences.getInstance()).getStringList(_key) ?? const [])
          .toSet();

  Future<void> save(Set<String> ids) async =>
      (await SharedPreferences.getInstance()).setStringList(_key, ids.toList());
}
