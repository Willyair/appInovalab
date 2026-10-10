import 'package:flutter/foundation.dart';

/// Sinal global de "os dados mudaram". Os serviços chamam [notificar] depois
/// de gravar; os ecrãs (dashboard, listas, separadores) ouvem e recarregam.
class Atualizacao {
  static final ValueNotifier<int> versao = ValueNotifier<int>(0);
  static void notificar() => versao.value++;
}
