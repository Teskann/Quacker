import 'package:material_ui/material_ui.dart';

class CombinedChangeNotifier extends ChangeNotifier {
  final ChangeNotifier one;
  final ChangeNotifier two;

  CombinedChangeNotifier(this.one, this.two) {
    one.addListener(() => notifyListeners());
    two.addListener(() => notifyListeners());
  }
}
