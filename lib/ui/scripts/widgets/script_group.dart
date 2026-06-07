import '../../../domain/models/script_entry.dart';

class ScriptGroup {
  final String name;
  final List<ScriptEntry> scripts;

  const ScriptGroup({required this.name, required this.scripts});
}
