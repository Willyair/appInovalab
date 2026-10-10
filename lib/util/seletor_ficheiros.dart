import 'package:file_picker/file_picker.dart';

class FicheiroEscolhido {
  final String caminho;
  final String nome;
  const FicheiroEscolhido(this.caminho, this.nome);
}

/// Único sítio que fala com o pacote file_picker (versão 13 ou superior).
/// Se a API mudar numa versão futura, só este ficheiro precisa de ajuste.
Future<FicheiroEscolhido?> escolherFicheiro() async {
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
  );
  if (f == null || f.path == null) return null;
  return FicheiroEscolhido(f.path!, f.name);
}
