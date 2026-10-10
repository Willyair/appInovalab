# estudos — InovaLab Crédito (protótipo local, SQLite)

Pacote renomeado para o projeto **estudos**, que já criaste com `flutter create`.
A funcionalidade não mudou — só o nome da pasta deste pacote.

Esta versão não usa servidor. Todos os dados ficam guardados só no
aparelho onde o app corre. É ideal para testar antes de ligar a
sincronização entre a MZN, a InovaLab e as Mamanas (próxima fase).

## 1. Dependências
No projeto `estudos`, instala os pacotes necessários:
```
cd estudos
flutter pub add sqflite sqflite_common_ffi path crypto fl_chart path_provider open_filex file_picker
```
(se já tinhas instalado os primeiros 4, só falta acrescentar o `fl_chart`,
usado nos gráficos do dashboard)

## 2. Copiar os ficheiros
Copia **o conteúdo** da pasta `lib` deste pacote para dentro de
`estudos/lib`, substituindo o que lá estiver.

Exemplo, a partir da pasta onde extraíste este zip:
```
cp -r lib/. /caminho/para/estudos/lib/
```
Repara no `/.` no fim — copia o conteúdo, não a pasta `lib` em si.
No fim, `estudos/lib/` deve ter exatamente: `main.dart`, `db/`, `models/`,
`screens/`, `services/` — nada de uma pasta `estudos` ou
`inovalab_credito_sqlite` lá dentro.

## 3. Executar
```
cd estudos
flutter run
```
(no teu caso, correste com `-d linux`; continua a funcionar)

Para Windows, é preciso o Visual Studio com a carga de trabalho
"Desenvolvimento para ambiente de trabalho com C++". Para iOS, é preciso
um Mac com Xcode (fica para mais tarde).

## 3b. Novidades da versão 2 (migração do schema + login seguro)
- Base de dados passa à **versão 2**. Se já tens a app instalada com dados
  da v1, a migração corre sozinha ao abrir (numa transação). Se algo correr
  mal, apaga a base de dados e recomeça — só tinha dados de demonstração.
- Novas tabelas: líderes e confirmações (§5), declaração do bairro, termos
  de compromisso/garantia (§9), fichas de visita (§10), ações de monitoria
  (§11), registo de atividade, e listas fixas de documentos e sinais de alerta.
- A base de dados agora recusa: pontuações acima dos máximos (20/20/25/15/10/10),
  tipos de documento/sinal que não estejam nas listas, decisões sem decisor,
  e alterações/apagamentos de decisões.
- Login: já **não lista nomes**. Entra-se com identificador + PIN
  (demo: `inovalab`, `mzn`, `258840000000`; PIN 1234 — mostrado só em debug).
  PIN com salt (PBKDF2), bloqueio de 5 min após 5 falhas, mensagem de erro
  sempre igual. IDs passam a UUID.

## 3h. Versão 8 (logo e ícone da Fundação)
- **Logo no cabeçalho** do início (branco, sobre o banner) e no **ecrã de login**
  (preto no tema claro, branco no escuro). Está embutido em
  `lib/widgets/logo_dados.dart`, por isso **não é preciso mexer no pubspec**.
- **Ícone da app (Android):** copia a pasta `android/` deste pacote por cima da
  do projeto (junta-se à que já existe; só acrescenta/substitui os ícones
  `mipmap-*` e cria `mipmap-anydpi-v26/ic_launcher.xml` e
  `values/ic_launcher_background.xml`). Depois faz **desinstalar a app do
  telemóvel** e `flutter run` de novo (o ícone só atualiza numa instalação nova).
- **Nome por baixo do ícone:** em `android/app/src/main/AndroidManifest.xml`,
  muda `android:label="estudos"` para `android:label="InovaLab Crédito"`.
- Logos originais usados: preto (claro), branco (escuro) e a marca "iL" azul
  (ícone). Para trocar o logo, fala comigo que gero o ficheiro de novo.

## 3g. Versão 7 (modo claro / escuro)
- Botão de aparência (sol / lua / automático) no **cabeçalho do início** e no
  **ecrã de login**. Opções: Claro, Escuro, Automático (segue o telemóvel).
- A escolha fica guardada neste aparelho e vale para todos os perfis.
- As cores de risco (verde / laranja / vermelho) têm tons próprios no escuro.

## 3f. Versão 6 (ecrãs da Mamana)
- **Acesso da Mamana:** na candidatura (InovaLab), ícone da chave. Cria o
  acesso com o **telefone** como identificador e um **PIN aleatório que só
  aparece uma vez** (entrega-se pessoalmente, com o consentimento dela). Se ela
  esquecer o PIN, o mesmo botão repõe-no.
- **Perfil Mamana** (demo: `258840000000`, PIN 1234) tem *Início*, *O meu pedido*
  e *Vendas*:
  - *O meu pedido*: frase simples sobre o ponto em que está, linha do tempo,
    decisão da MZN **com a fundamentação**, documentos (pode **enviar** o que
    falta, até o pedido seguir para a MZN; fica "por validar" até a InovaLab
    conferir) e plano de pagamentos.
  - *Vendas*: regista o total de cada mês (fica "declarado"; se a InovaLab já
    confirmou o mês, não se sobrepõe).
  - Menu (3 pontos) -> **Alterar PIN**.
- A Mamana **não vê** a pontuação interna nem os sinais de alerta; vê o estado,
  as decisões e o que lhe diz respeito. Rever com a Fundação.

## 3e. Versão 5 (ecrãs da MZN e encaminhamento)
- **InovaLab → MZN:** no separador *Risco*, o botão "Encaminhar à MZN" só fica
  ativo com a análise financeira feita, o risco classificado (e atualizado) e
  os documentos essenciais entregues. Depois de encaminhada, a análise fica
  **bloqueada**. Se o risco for elevado, pede confirmação da revisão interna.
- **Perfil MZN** (`mzn` / PIN 1234) tem agora: *Início*, *Decisões* e *Atrasos*.
  - Decisões: vê só o que foi encaminhado (risco, fatores, financeira,
    documentos com anexos, verificações, sinais) e **aprova, pede mais
    informação ou recusa**, sempre com fundamentação, gravada com o nome de
    quem decidiu e **sem poder ser alterada**.
  - "Pedir mais informação" devolve a candidatura à InovaLab, que corrige e
    volta a encaminhar; a fundamentação aparece no separador *Risco*.
  - Aprovada → "Formalizado" → "Desembolsado" → plano e registo de pagamentos.
  - Atrasos: lista por dias, com os escalões de `configuracoes`
    (1 dia = InovaLab acompanha; 8 = aviso à MZN; 30 = revisão).
- Como testar o ciclo completo: cria candidatura (InovaLab) → completa →
  classifica → encaminha → sai → entra como `mzn` → decide.

## 3d. Versão 4 (correções + anexos + acompanhamento)
- **Novas dependências** (corre uma vez na pasta do projeto):
  `flutter pub add path_provider open_filex file_picker`
- **Linux:** o seletor de ficheiros precisa de `zenity` (ou `kdialog`) e abrir
  ficheiros precisa de `xdg-utils`: `sudo apt install zenity xdg-utils`.
- Dashboard, lista, separadores e risco **atualizam sozinhos** quando algo muda.
- **Anexar ficheiros** (PDF/JPG/PNG, até 10 MB) a cada documento: anexar,
  abrir, substituir, remover. Ficam em `anexos/` na pasta de dados da app.
- **Editar** candidatura (ícone de lápis), até ser decidida.
- Novo separador **Acompanhamento**: plano de pagamentos (valor ÷ prazo), registo
  de pagamentos, vendas conferidas e ações. Isto é o que alimenta os gráficos.
- Como a decisão da MZN ainda não tem ecrã, há um menu de programador (ícone de
  insecto, só em debug) para definir o estado, p.ex. "Crédito formalizado".

## 3c. Novidades da versão 3 (ecrãs da InovaLab)
Entra como `inovalab` e aparece uma barra em baixo: **Início** e **Candidaturas**.
- **Nova candidatura**: beneficiária, negócio e pedido. Cria logo o checklist
  com os 8 documentos do §4.
- **Documentos**: marca o que foi entregue (validade e observação à parte).
- **Verificação**: identidade, declaração do bairro, confirmação de líderes
  (só factos verificáveis) e ficha de visita.
- **Financeira**: vendas, custos, dívidas e prestação; calcula excedente,
  cobertura e sugere a pontuação de capacidade.
- **Risco**: 6 dimensões (20/20/25/15/10/10), sinais de alerta e justificação
  obrigatória. "Guardar e classificar" dá Baixo/Moderado/Elevado **com os fatores**.
- Só a InovaLab altera; a decisão de crédito continua a ser da MZN (ecrã por fazer).
- A lógica de risco está em `services/risco_service.dart` (sem base de dados) e
  tem testes: `flutter test`.
- Regras da classificação (propostas, a validar com a MZN): sinal grave ou
  documento essencial em falta (identificação, prova do negócio) => elevado;
  sinal leve, documento obrigatório em falta ou capacidade < 12/25 => no máximo
  moderado.

## 4. Como testar
Na primeira vez que o app abre, ele cria sozinho **3 contas de
demonstração**, uma por perfil, todas com o PIN **1234**:
- Técnico InovaLab (demo)
- Analista MZN (demo)
- Mamana Teste

No ecrã de login, escreve o identificador (ver acima) e o PIN `1234`.
Agora já cai diretamente no **dashboard**.

O título do app continua a mostrar "InovaLab Crédito" — isso é só o
nome visível dentro da aplicação, não tem relação com o nome `estudos`
do projeto Flutter (a pasta/pacote).

## 5. O que ver no dashboard
Na primeira vez que entras, o app semeia sozinho alguns dados de
exemplo (2 novidades, 2 parceiros, 3 candidaturas com estados e riscos
diferentes, pagamentos e 6 meses de vendas), para os gráficos não
aparecerem vazios. Isto só acontece uma vez.

- **Header**: banner (por agora um gradiente de cor — ver nota abaixo),
  logo, botão de sair, iniciais do perfil e o slogan.
- **Novidades**: carrossel com indicadores de página.
- **Gráficos**: entra como **Mamana** e vês pagamentos e vendas só dela;
  entra como **MZN** ou **InovaLab** e vês os números acumulados de
  todas as Mamanas (pagamentos em dia/atrasados, distribuição de risco,
  crescimento médio dos negócios) — sem nomes, só agregados.
- **Sobre a InovaLab**: texto editável (por agora, só pela base de dados).
- **Parceiros e financeiros**: carrossel com a MZN e a InovaLab.

### Sobre as imagens (banner e logo)
Por agora, o banner é um gradiente de cor e o logo é um ícone — ainda
não há imagens reais nem forma de as carregar no app. Quando tiveres as
imagens (do banner e dos logos), digo-te como as adicionar; a forma mais
simples no protótipo é como "assets" dentro do próprio projeto.

### Apagar os dados de exemplo
Se mais tarde quiseres recomeçar do zero (sem os dados de demonstração),
apaga o ficheiro da base de dados do SQLite e corre o app de novo — ele
recria tudo, incluindo as contas de demonstração. O caminho típico no
Linux é algo como `~/.local/share/<nome_do_pacote>/estudos/` — mais
simples é apagar a pasta `estudos` do dispositivo onde a app guarda
dados, ou perguntar-me e eu indico o caminho exato para o teu sistema.

## Próximos passos
1. Confirmar que o dashboard corre bem e os 3 perfis mostram o que devem.
2. Construir os ecrãs de candidatura, checklist, análise e pontuação
   (o trabalho principal da InovaLab), ainda em modo local.
3. Depois, os ecrãs da MZN (decisão, pagamentos) e da Mamana (o seu
   pedido, envio de documentos, registo de vendas).
4. Só no fim, desenhar a sincronização entre aparelhos.
