# Correções da revisão da v8

Revisão feita **a ler o código** (não havia Flutter/Dart disponível para compilar
ou correr). Depois de copiares, corre `flutter analyze` e `flutter test`.

## Erros silenciosos (não davam mensagem nenhuma)

| # | Onde | O que acontecia | Correção |
|---|------|-----------------|----------|
| 1 | `widgets/comum.dart` → `lerNumero` | "15.000" era lido como **15 MZN** (o ponto virava decimal). Também aceitava "NaN"/"Infinity". | Lê "15.000", "15 000", "15.000,50", "15,000.50", "1500,5". Rejeita NaN/Infinity. Teste novo: `test/comum_test.dart`. |
| 2 | `dashboard_service` | "Pagamentos em dia" contava **todos os pagos**, mesmo pagos com atraso. | Em dia = pago até à data prevista; pago depois conta como atrasado. |
| 3 | `dashboard_service` | Pagamento previsto para **hoje** contava como atrasado (comparava com a hora exata). Inconsistente com os ecrãs, que comparam só o dia. | Compara só o dia. |
| 4 | `dashboard_service` | "Valor concedido" e "Mamanas apoiadas" incluíam pedidos recém-recebidos, em análise ou encaminhados; no perfil da Mamana mostrava o valor pedido até de pedidos **recusados**. | Só conta estados aprovados (decidida, formalizada, desembolsada, em_monitoria). |
| 5 | `candidatura_service.gerarPlanoPagamentos` | Gerar o plano com o crédito "formalizado" passava o estado a `em_monitoria` e **saltava o desembolso**; a MZN já não conseguia marcar "desembolsado". | O plano só se cria em `desembolsada`/`em_monitoria` (serviço e os dois ecrãs). |
| 6 | `candidatura_service.registarPagamento` | Se o pagamento não existisse (ou já estivesse pago) não acontecia nada, mas a app dizia "ok" e registava a atividade. Também sobrepunha pagamentos já registados. | Falha com mensagem; só regista pagamentos ainda por pagar. |
| 7 | `tab_financeira` | Texto que não fosse número (ex.: "5000MZN") era lido como **0** e a análise guardava-se sem aviso. | Valida cada campo; recusa texto e negativos. |
| 8 | `mzn_service.decidir` | Dois toques seguidos em "Aprovar" gravavam **duas decisões** — e decisões não se podem apagar. | O estado é confirmado dentro da transação. |
| 9 | `mamana_pedido_screen` | Num pedido recusado, "Análise concluída" e "Enviado à MZN" apareciam por fazer. | A linha do tempo vai até "encaminhada" e para na decisão. |
| 10 | `registarVenda` / `declararVenda` | Mês "26-10" gravava o ano 26 (lixo na ordenação e nos gráficos); a InovaLab podia registar meses futuros. | Ano ≥ 2000 e mês até ao atual. |
| 11 | `anexarDocumento` | A beneficiária podia, pelo serviço, substituir um documento já validado (o ecrã escondia o botão, o serviço não recusava). | O serviço recusa. |
| 12 | `nova_candidatura_screen` | Editar um pedido de 15000.50 e gravar passava a 15001 (arredondava). | Mantém os decimais. |
| 13 | `auth_service.entrar` | "+258 84 000 0000" ou "Inovalab" não davam entrada (o identificador guardado é só dígitos/minúsculas). | Normaliza o identificador. |
| 14 | `grafico_acompanhamento` | O eixo dos meses podia repetir o mesmo mês (intervalo 0.5). | `interval: 1`. |
| 15 | `grafico_acompanhamento` | Gráficos mostravam "MT 15000"; o resto da app "15 000 MZN". | Usa `formatarMzn`. |

## Erros que escondiam falhas (spinner infinito / nada acontecia)

- `login_screen`: se a base de dados falhasse ao abrir, o ecrã ficava a rodar para
  sempre; e erros que não fossem `LoginException` não mostravam nada ao tocar em "Entrar".
  Agora mostram a mensagem e há "Tentar de novo".
- `tema_service.carregar`: engolia o erro de abrir a base (`catch (_)`). Agora regista-o.
- `dashboard_screen`: qualquer exceção deixava o spinner para sempre. Agora mostra o erro + "Tentar de novo".
- `mamana_pedido_screen`: falha ao carregar documentos/pagamentos não mostrava nada.
- `nova_candidatura_screen` (modo editar): falha ao carregar = spinner infinito.
- `database_helper`: dois pedidos simultâneos à base podiam abri-la duas vezes; e uma abertura falhada
  ficava para sempre. Agora guarda a abertura em curso e esquece-a se falhar.
- `mzn_detalhe_screen`: depois de "Pedir mais informação" o ecrã passava a mostrar um erro
  (a candidatura deixa de ser visível para a MZN). Agora fecha.

## NÃO corrigi (decisões tuas / mais trabalho)

1. **Contas de demonstração (PIN 1234, incluindo a MZN) criam-se também em versões finais.**
   Só o *texto* no login é escondido fora do debug. Quem instalar a app entra como MZN e decide créditos.
2. **Dados de demonstração misturam-se com os reais** nos gráficos agregados (a semente corre sempre que existe "Mamana Teste").
3. **Pagamento parcial conta como pago por inteiro** (basta haver `data_pagamento`). Um pagamento de 100 numa prestação de 2 500 sai dos "Atrasos".
4. **`validade` dos documentos nunca é avaliada**: um documento caducado continua "entregue". As datas são texto livre, sem validação de formato.
5. **Encaminhar à MZN não exige verificações** (identidade, comunitária, visita), e um resultado "inconsistente" não bloqueia nem cria sinal de alerta.
6. **Documento "Termo de compromisso" é obrigatório já na classificação de risco**, mas só existe na formalização: na prática nenhum pedido chega a risco "baixo" até ser marcado como entregue. A validar com a MZN.
7. **Caixas "confirmado" vêm marcadas por defeito** nas confirmações de líder e nas fichas de visita: é fácil gravar uma confirmação sem a ter feito.
8. **Leituras sem controlo de perfil** nos serviços (`avaliacao`, `sinais`, `vendas`…): só o ecrã impede a Mamana de ver a pontuação. Ao passar para servidor tem de ser o servidor a decidir.
9. **A base no Linux/Windows (ffi) guarda-se relativa à pasta onde a app arranca**; noutra pasta parece que "perdeste os dados". Usar `getApplicationSupportDirectory()` (já tens o `path_provider`).
10. Migração v1→v2: documentos/sinais antigos com `tipo` fora das listas fixas desaparecem das listas (o `join` não os encontra). Só afeta bases v1 com texto livre.
11. Bloqueio de 5 min após 5 falhas é por conta: qualquer pessoa pode bloquear a conta da MZN de propósito.
12. `file_picker`: `FilePicker.pickFile` (v13+) não consegui verificar sem Flutter; se `flutter analyze` queixar-se, só mexe em `util/seletor_ficheiros.dart`.
