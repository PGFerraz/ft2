# AgendaIA

Agente de agendamento heurístico em Flutter/Dart. Ele recebe tarefas (duração, prazo, urgência e importância) e compromissos fixos, aplica uma base de regras para sugerir prioridades e distribui as tarefas nos horários livres usando **busca gulosa** e **A\***.

Projeto do Bloco 3 da disciplina de Inteligência Artificial (Engenharia da Computação, FAINOR, 2026). A especificação está no documento do Bloco 2.

## Requisitos

| Ferramenta | Versão usada | Observação |
|---|---|---|
| Flutter | 3.47.9 (canal stable) | inclui o Dart 3.13.7 |
| Git | qualquer recente | o Flutter precisa do `git` no `PATH` |
| Google Chrome ou Microsoft Edge | recente | para executar a versão web |
| Android Studio + Android SDK | opcional | apenas para gerar o APK |
| Visual Studio 2022 com "Desktop development with C++" | opcional | apenas para a versão Windows |

Confira o ambiente com `flutter doctor`. Para a versão web, basta que as linhas **Flutter** e **Chrome** estejam marcadas.

## Como executar

```bash
git clone <url-do-repositorio>
cd AgendaIA_Bloco3/agenda_ia
flutter pub get
flutter run -d chrome
```

Na primeira abertura a agenda está vazia. Em **Preferências → Carregar cenário de demonstração** há um conjunto de tarefas e compromissos relativos ao dia atual, com um conflito proposital e um histórico que ativa a regra R7.

### Build de produção (web)

```bash
flutter build web --release --no-web-resources-cdn
```

O resultado fica em `build/web/` e pode ser servido por qualquer servidor de arquivos estáticos. A opção `--no-web-resources-cdn` embute o renderizador (CanvasKit) no build, de modo que o aplicativo não depende de CDN externa (RNF02).

O servidor precisa entregar `sqlite3.wasm` com o tipo `application/wasm`.

### Persistência na web

Os dados ficam em SQLite compilado para WebAssembly e são gravados no IndexedDB do navegador. Os arquivos `web/sqlite3.wasm` e `web/sqflite_sw.js` já estão no repositório. Se o pacote `sqflite_common_ffi_web` for atualizado, gere-os de novo com:

```bash
dart run sqflite_common_ffi_web:setup
```

Se o banco não abrir em até 10 s, o aplicativo continua funcionando em memória e mostra um aviso no topo. Para forçar esse modo (por exemplo, numa apresentação em computador desconhecido):

```bash
flutter run -d chrome --dart-define=AGENDA_MEMORIA=true
```

### Android e Windows

```bash
flutter build apk --release      # requer Android SDK
flutter build windows --release  # requer Visual Studio com C++
```

No Android o SQLite usa o plugin nativo do `sqflite`; no Windows, o `sqflite_common_ffi`. Até agora o aplicativo foi testado apenas na web e nos testes automatizados; os builds Android e Windows ainda não foram executados.

## Testes

```bash
flutter test                         # todos os testes (56)
flutter test test/domain             # motor de busca e regras, sem interface
dart run tool/benchmark.dart 100     # comparativo gulosa × A* (Tabela 10)
```

| Arquivo | O que valida |
|---|---|
| `test/domain/conflicts_test.dart` | sobreposição de intervalos e detecção de conflitos (RF03) |
| `test/domain/rule_engine_test.dart` | regras R1 a R7 e a ordem de encadeamento |
| `test/domain/search_test.dart` | função de custo, heurística, gulosa, A*, pausas, limite de nós |
| `test/domain/admissibility_test.dart` | h(n) ≤ custo ótimo e consistência em 100 instâncias aleatórias; A* = busca exaustiva |
| `test/domain/performance_test.dart` | tempo do A* com 5, 8, 10 e 12 tarefas (RNF01) |
| `test/data/sqlite_repository_test.dart` | gravação e leitura no SQLite real, restrições do esquema |
| `test/widget/app_flow_test.dart` | fluxos de interface em tela de celular (390 px) e desktop (1366 px) |

O resultado mais recente do benchmark está em `docs/resultados_benchmark.md`.

## Estrutura do código

```
lib/
  domain/                  Dart puro, sem Flutter (RNF03)
    entities.dart          entidades da Tabela 5
    conflicts.dart         teste de sobreposição e detecção de conflitos
    rules/rule_engine.dart base de regras R1–R7 e motor de encadeamento para frente
    planning/
      problem.dart         discretização em slots de 15 min, tabela de encaixe
      search_core.dart     custo de passo, heurística, transição e fechamento
      greedy.dart          busca gulosa (Quadro 2)
      astar.dart           A* com poda por dominância, limite de nós e limite superior guloso (Quadro 1)
      exhaustive.dart      busca exaustiva usada como referência nos testes
      planner_service.dart converte tarefas e compromissos em problema e resultado em datas
      instance_generator.dart  instâncias aleatórias para testes e benchmark
  data/                    persistência (SQLite em todas as plataformas)
  state/                   estado com Riverpod e cenário de demonstração
  ui/                      telas T1–T8, tema e widgets responsivos
test/                      testes unitários, de dados e de widget
tool/benchmark.dart        experimento comparativo
```

## Rastreabilidade dos requisitos

| Requisito | Onde está |
|---|---|
| RF01 tarefas | `ui/screens/task_form_screen.dart`, `task_list_screen.dart`, `task_detail_screen.dart` |
| RF02 compromissos | `ui/screens/event_form_screen.dart` |
| RF03 conflitos | `domain/conflicts.dart`, `ui/screens/conflicts_screen.dart` |
| RF04 gulosa | `domain/planning/greedy.dart` |
| RF05 A\* | `domain/planning/astar.dart` |
| RF06 comparação | `ui/screens/plan_result_screen.dart` |
| RF07 prioridade por regras | `domain/rules/rule_engine.dart` |
| RF08 replanejamento | `ui/screens/task_detail_screen.dart` (concluir, atrasar, replanejar) |
| RF09 texto livre com Gemini | **não implementado** (opcional no Bloco 2) |
| RNF01 < 2 s com 10 tarefas | `test/domain/performance_test.dart` |
| RNF02 offline e local | SQLite local; CanvasKit embutido no build web |
| RNF03 motor isolado | `lib/domain/` não importa Flutter |
| RNF04 SUS | depende de teste com usuários (fora do código) |

## Decisões de implementação que diferem do texto do Bloco 2

- **Fechamento de estados.** Quando uma tarefa não cabe mais no horizonte a partir do instante t, ela é marcada como não alocada imediatamente, com a penalidade descrita na Seção 3.4. Como t só cresce, isso não muda a solução ótima e reduz o número de ramificações.
- **Penalidade de não alocação.** É w × (pior atraso possível no horizonte + 1000 slots). Assim, deixar uma tarefa de fora sempre custa mais do que alocá-la com atraso, e a heurística continua admissível.
- **Folga na poda por dominância.** Um estado só elimina outro com o mesmo conjunto de tarefas restantes quando o custo dele, somado a uma folga de α (troca de tipo) e de β por tarefa restante que prefere o pico, não supera o do outro. Sem essa folga a poda poderia descartar o ótimo; o teste `admissibility_test.dart` compara o A* com a busca exaustiva para confirmar.
- **Preferência de pico.** Vale para tarefas do tipo foco (Seção 3.4) e para as que dispararam R2 (Tabela 4).
- **Peso w.** É igual à prioridade (1 a 4).
- **SQLite na web.** Usa a variante do `sqflite_common_ffi_web` que roda sem web worker, porque a variante com SharedWorker não inicializou em todos os navegadores testados.
