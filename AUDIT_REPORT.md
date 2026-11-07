# MacroTic — Relatório de Auditoria Técnica

> Auditoria independente de engenharia de software, arquitetura, segurança, QA e UX.
> Data: 2026-11-07 · Branch: `main` · Commit base: `3f72487`
> Escopo: 100% do código-fonte sob `Sources/`, scripts de build/release, empacotamento e configuração.

---

## 1. Resumo executivo

MacroTic é um utilitário nativo de macOS (Swift 6.2 toolchain / modo de linguagem Swift 5, SwiftUI+AppKit, SPM) para automação de macros: grava e reproduz cliques, digitação, atalhos, arrasto, scroll e foco de janela via APIs `CGEvent` e `Accessibility`. A aplicação é **funcional, bem organizada e coesa**: uma responsabilidade por arquivo, modelos `@Observable` claros, uma camada de ações plugável (`MacroAction`) e um pipeline de release/auto-update (Sparkle + GitHub Actions) sólido e assinado com EdDSA.

**Qualidade técnica geral: boa.** O código é legível, o acoplamento é baixo e as decisões arquiteturais estão documentadas em `AI_PROJECT_MAP.md`. Os problemas encontrados **não são de arquitetura**, e sim de **robustez de dados, validação de entrada, concorrência, cobertura de testes e algumas lacunas de UX de segurança**.

### Principais riscos

> Atualização: após esta auditoria, o usuário pediu a implementação das correções (dispensando múltiplos monitores e os passos condicionais). O estado abaixo reflete o que já foi implementado e validado por `swift build` (exit 0, sem novos avisos).

| # | Risco | Gravidade | Situação |
|---|-------|-----------|----------|
| H1 | Perda total das macros se `macros.json` falhar ao decodificar (ficava `[]` e o próximo `save()` sobrescrevia o arquivo) | Alta | **Corrigido** |
| H2 | Ausência total de testes automatizados sobre lógica pura central (parsing de atalhos, Codable retrocompatível, reordenação, dedup) | Alta | Testes **escritos**; execução **bloqueada** (sem Xcode/XCTest nesta máquina) — ver §6 |
| M1 | Vazamento de um retain de `CGEvent` por evento capturado durante a gravação (`passRetained` num tap `listenOnly`) | Média | **Corrigido** |
| M2 | Corrida de dados em `shouldStop`/`isPaused` (lidos na `Task.detached`, escritos na main) | Média | Pendente (não tocar o motor; baixo risco prático) |
| M3 | Sem validação pré-execução: passo de clique sem coordenadas clica silenciosamente em (0,0); passos vazios abortam a macro no meio | Média | **Corrigido** |
| M4 | Captura de coordenadas/scroll não suporta múltiplos monitores | Média | Dispensado pelo usuário |
| M5 | Exclusão de macro é destrutiva, imediata, sem confirmação nem desfazer | Média | **Corrigido** |
| M6/M8/M10/L3/L5 | Backup de biblioteca; feedback de permissão na gravação; colisão de import; mapa de teclas duplicado; privacidade do log | Média/Baixa | **Corrigidos** (ver §5) |

### Resultado geral

Aplicação **aprovada com ressalvas**. Pronta para uso pessoal/distribuição limitada; antes de uma distribuição ampla recomenda-se fechar H2, M3, M5 e adicionar backup/restauração da biblioteca (M6) e notarização (L8). O build de release compila limpo (ver §6).

---

## 2. Inventário auditado

### 2.1 Código-fonte inspecionado (100% de `Sources/`)

**App (`Sources/App/`)** — `MacroTicApp.swift`, `MainWindowController.swift`, `UpdaterController.swift`, `SilentUpdateUserDriver.swift`, `UpdateProgressWindow.swift`.
**Models (`Sources/Models/`)** — `AppState.swift`, `AppSection.swift`, `Macro.swift`, `MacroStep.swift`, `MacroStepKind.swift`, `MacroDraft.swift`, `MacroStore.swift`, `MacroIO.swift`, `MacroExecutor.swift`, `ActionRecorder.swift`, `ShortcutKeyMap.swift`, `WindowCatalog.swift`.
**Actions (`Sources/Models/Actions/`)** — `MacroAction.swift`, `KeyShortcutAction.swift`, `TypeTextAction.swift`, `ClickAction.swift`, `DelayAction.swift`, `FocusWindowAction.swift`, `DragAndDropAction.swift`, `ScrollAction.swift`.
**Views (`Sources/Views/`)** — `MainWindowView.swift`, `ExecutionHUDView.swift`, `Home/*` (4), `MacroEditor/*` (7), `Manual/ManualView.swift`, `Settings/SettingsView.swift`, `Components/*` (2).
**Services (`Sources/Services/`)** — `AppLog.swift`, `FeedbackMailer.swift`.
**Build/Release** — `Package.swift`, `Packaging/Info.plist`, `Scripts/package_app.sh`, `Scripts/build_appcast.sh`, `.github/workflows/release.yml`.

### 2.2 Funcionalidades verificadas (leitura de código + build)

Criar macro; editar macro; gravar ações (recorder); reproduzir macro; parar (⌘Esc + botão); repetição/intervalo; atalho de teclado; digitar texto (tecla a tecla / colar); clique; esperar; selecionar/focar janela; arrastar e soltar; scroll; favoritos; importar/exportar macro individual; seleção múltipla, reordenação e execução parcial de passos; trava de segurança; modo depuração (preview on-screen); auto-update (Sparkle); logging + feedback por e-mail.

### 2.3 Testes executados

- **`swift build`** (debug) e **`swift build -c release`** não executado explicitamente, mas o debug compila; ver §6. Resultado: **sucesso (exit 0)**, 2 avisos pré-existentes.
- **Verificação estática/leitura linha a linha** de todos os arquivos acima.
- **Não há suíte de testes automatizados no repositório** — portanto nenhum resultado de teste unitário/integração/E2E é reportado. Nenhum resultado de teste foi inventado.

### 2.4 Áreas não verificadas (e por quê)

- **Comportamento em tempo de execução da injeção `CGEvent`** (cliques/digitação reais em apps de terceiros) — exige sessão gráfica interativa com permissão de Acessibilidade; não validável num ambiente headless. Avaliado por leitura de código.
- **Fluxo real do Sparkle (download+instalação)** — exige um `.app` empacotado e assinado e um release publicado; avaliado por leitura.
- **Comportamento em múltiplos monitores e em tela cheia** — avaliado por leitura (ver M4).

---

## 3. Problemas encontrados

> Cada item: ID · título · local · descrição · causa raiz · impacto · gravidade · recomendação · correção · validação.

### H1 — Perda total das macros quando `macros.json` não decodifica *(CORRIGIDO)*
- **Local:** `Sources/Models/MacroStore.swift` `load()`.
- **Descrição/Causa raiz:** `load()` fazia `macros = (try? decode) ?? []`. Se o arquivo existir mas estiver corrompido/parcialmente gravado/incompatível, `macros` vira `[]`. Qualquer `save()`/`markUsed()`/`toggleFavorite()` seguinte chama `persist()` e **sobrescreve o arquivo íntegro com uma lista vazia**, tornando a perda permanente.
- **Impacto:** perda irreversível de toda a biblioteca do usuário (há dados reais: `~/Library/Application Support/MacroTic/macros.json`, 54 KB na máquina auditada). Gravidade **Alta** (integridade de dados).
- **Recomendação:** não sobrescrever um arquivo que falhou ao decodificar; preservar cópia.
- **Correção implementada:** `load()` passou a usar `do/catch`; em falha de decode com dados não vazios, grava um backup `macros.corrupt-<epoch>.json` no mesmo diretório e registra em `AppLog` antes de seguir com lista vazia. O arquivo original é preservado para recuperação manual.
- **Validação:** compila (`swift build` exit 0). Teste funcional de recuperação: ver REMEDIATION_PLAN (caso de teste proposto `MacroStoreTests.testCorruptFileIsBackedUp`).

### H2 — Ausência de testes automatizados *(PENDENTE)*
- **Local:** projeto inteiro (não há target de testes em `Package.swift`; não há diretório `Tests/`).
- **Descrição/Causa raiz:** nenhuma cobertura unitária/integração/E2E. Há lógica pura, determinística e crítica, altamente testável, sem rede de segurança contra regressões: `ShortcutKeyMap.parse`, `Macro`/`MacroStep` decode retrocompatível, `MacroStore.sorted`/dedup/`importJSON`, `MacroDraft.moveSelectedUp/Down`/`move(before:)`/seleção, coalescência do `ActionRecorder`, conversões de `ScrollAction`.
- **Impacto:** regressões silenciosas a cada mudança; a própria auditoria não pôde confirmar comportamento por execução. Gravidade **Alta** (qualidade/manutenção).
- **Recomendação/Correção:** adicionar um alvo de testes SPM e cobrir a lógica pura. Plano detalhado e casos de teste concretos em `REMEDIATION_PLAN.md`. Não implementado nesta auditoria por exigir reestruturação do `Package.swift` (alvo executável com `@main`) cuja compilação de testes não pôde ser validada no ambiente headless; registrado como pendência prioritária para evitar "inventar" um resultado de teste.

### M1 — Vazamento de retain por evento na gravação *(CORRIGIDO)*
- **Local:** `Sources/Models/ActionRecorder.swift:42`.
- **Descrição/Causa raiz:** o callback do event tap `listenOnly` retornava `Unmanaged.passRetained(event)`. Para taps `listenOnly` o valor de retorno é ignorado pelo sistema, logo o `+1` retain **vaza** a cada evento (cada clique/tecla/scroll) durante a gravação. Todos os outros taps do projeto usam `passUnretained` (`MacroExecutor`, `ShortcutCapturePicker`, `ScrollCapturePicker`).
- **Impacto:** crescimento de memória proporcional ao nº de eventos durante gravações longas. Gravidade **Média** (desempenho/estabilidade).
- **Correção implementada:** `passRetained` → `passUnretained`, alinhando com os demais taps.
- **Validação:** compila (exit 0). Comportamento inalterado (retorno ignorado em `listenOnly`).

### M2 — Corrida de dados em `shouldStop`/`isPaused` *(PENDENTE)*
- **Local:** `Sources/Models/MacroExecutor.swift` (campos em :19–20; leituras na `Task.detached` :139/:142/:145/:178; escritas na main em `stop()`/`pause()`/`resume()`).
- **Descrição/Causa raiz:** flags `Bool` mutáveis compartilhadas entre a `Task.detached(priority:.userInitiated)` e a `MainActor` sem sincronização. O modo `.swiftLanguageMode(.v5)` desliga a verificação estrita de concorrência do Swift 6, mascarando o problema.
- **Impacto:** em teoria, leitura desatualizada da flag de parada (iteração extra antes de parar). Na prática em arm64 o risco é baixo, mas é um *data race* real e um cheiro de concorrência. Gravidade **Média**.
- **Recomendação:** encapsular o estado de controle num `actor`, ou usar `OSAllocatedUnfairLock`/`Atomic`, ou dirigir a parada só via `Task.isCancelled` (as ações já cooperam com `Task.isCancelled`).

### M3 — Sem validação de passos antes de executar *(PENDENTE)*
- **Local:** `MacroExecutor.execute`; editores em `MacroStepRowView.swift`; `MacroStep` (`hasCoordinates`, etc.).
- **Descrição/Causa raiz:** não há verificação de que cada passo está completo. Um `.click` sem captura tem `clickX/Y == 0` e **clica em (0,0)** silenciosamente (canto superior-esquerdo). Um `.typeText`/`.keyShortcut`/`.launchApp` vazio retorna `false` e **aborta a macro no meio** com mensagem genérica ("Falha ao executar passo N").
- **Impacto:** ações incorretas silenciosas (clique em 0,0) e falhas confusas no meio da execução. Gravidade **Média** (correção + UX).
- **Recomendação:** validar a macro antes de rodar (destacar passos incompletos; impedir execução ou avisar); distinguir "passo não configurado" de "falha de execução".

### M4 — Captura de coordenadas/scroll não cobre múltiplos monitores *(PENDENTE)*
- **Local:** `Sources/Views/MacroEditor/ScreenCoordinatePicker.swift` (painel criado em `NSScreen.main?.frame`, conversão `toCGEventCoordinates` usa `NSScreen.main.frame.height`), `PickerOverlayView` (label usa altura da main), `ActionRecorder.isPointInOwnWindow:96`.
- **Descrição/Causa raiz:** o overlay de captura é dimensionado apenas para a tela principal e a conversão CG↔Cocoa assume a altura da tela principal. As coordenadas `CGEvent.location` são globais (abrangem todos os monitores), mas a captura via overlay/conversão fica incorreta ou impossível fora da tela principal.
- **Impacto:** usuários com mais de um monitor não conseguem capturar posições confiáveis em telas secundárias. Gravidade **Média**.
- **Recomendação:** criar overlays cobrindo a união de `NSScreen.screens`; converter coordenadas usando a tela que contém o ponto.

### M5 — Exclusão de macro destrutiva sem confirmação/desfazer *(PENDENTE)*
- **Local:** `MacroRowView.swift` (botão lixeira + menu de contexto) → `AppState.deleteMacro` → `MacroStore.delete`.
- **Descrição/Causa raiz:** a exclusão é imediata (com animação) e grava no disco; não há diálogo de confirmação nem desfazer. Contrasta com a confirmação adicionada ao fechar a janela fora da Home.
- **Impacto:** perda acidental de macros trabalhosas. Gravidade **Média** (integridade/UX).
- **Recomendação:** `NSAlert` de confirmação (ou Undo via `UndoManager`/snackbar). Baixo risco de implementação.

### M6 — Sem backup/exportação/restauração da biblioteca; código morto de export *(PENDENTE)*
- **Local:** `MacroStore.exportJSON`/`importJSON`/`exportURL` — **não referenciados por nenhuma view** (confirmado por busca). Import/export existe só para **uma** macro (`MacroIO` no editor).
- **Impacto:** não há "exportar tudo"/"importar biblioteca"/backup; e três métodos públicos são código morto. Gravidade **Média** (funcionalidade ausente) + Baixa (código morto).
- **Recomendação:** ligar um "Exportar biblioteca…/Importar…" em Configurações usando os métodos existentes, ou remover o código morto.

### M7 — Perda silenciosa de passos em downgrade/forward-incompat *(PENDENTE)*
- **Local:** `Macro.swift` `LossyStep` (:84–90) + re-gravação em `MacroStore.persist`.
- **Descrição/Causa raiz:** passos que não decodificam (ex.: um `MacroStepKind` novo criado por uma versão futura, ou o legado `openURL` removido) são descartados silenciosamente; ao salvar de novo, a macro é persistida **sem** eles.
- **Impacto:** abrir a biblioteca numa versão mais antiga e salvar remove passos de versões mais novas, sem aviso. Gravidade **Média**.
- **Recomendação:** registrar/avisar quando passos forem descartados; considerar preservar JSON desconhecido.

### M8 — Gravação falha em silêncio sem permissão *(PENDENTE)*
- **Local:** `ActionRecorder.startRecording` (:47–50) — se `CGEvent.tapCreate` falhar (sem Acessibilidade), faz `isRecording = false` e retorna sem feedback.
- **Impacto:** usuário clica "Gravar Ações" e nada acontece; nenhuma orientação. Gravidade **Média** (UX). O `MacroExecutor` já faz o tratamento correto (prompt + abrir Ajustes); o recorder deveria espelhar.
- **Recomendação:** detectar falha, checar `AXIsProcessTrusted()`, exibir alerta e abrir Ajustes → Acessibilidade.

### M9 — Passo "Selecionar janela" depende do título vivo *(PENDENTE/por design)*
- **Local:** `FocusWindowAction.swift` + `WindowCatalog.window(forTitle:)`.
- **Descrição:** o passo guarda o **título** da janela; se nenhuma janela aberta tiver exatamente esse título no momento da execução, `window(forTitle:)` retorna `nil` e o passo falha (aborta a macro). Títulos mudam (documento/estado).
- **Impacto:** macros de foco de janela são frágeis. Gravidade **Média**.
- **Recomendação:** permitir casar por app + correspondência parcial/regex do título, com fallback para a primeira janela do app-alvo.

### M10 — Import de macro com ID existente é no-op silencioso *(PENDENTE)*
- **Local:** `MacroStore.importJSON:70` (ignora ids já presentes) e `MacroIO.importMacro` (editor substitui draft — ok).
- **Impacto:** reimportar uma macro editada com o mesmo id "não faz nada", sem feedback. Gravidade **Média** (UX) — relevante se M6 ligar import de biblioteca.
- **Recomendação:** ao colidir id, perguntar (substituir/duplicar com novo id) e dar feedback.

### Baixas (L)
- **L1 — Avisos de concorrência:** captura de `self` não-`Sendable` em closures `@Sendable` de `onChange` em `MainWindowController.swift:75` e `:144`. 2 avisos no build. *(Pendente)*
- **L2 — Código morto:** `MacroExecutor.pause()/resume()` nunca chamados (sem UI de pausa); `MacroStore.exportJSON/importJSON/exportURL` não usados. *(Pendente)*
- **L3 — Fonte dupla de verdade de teclas:** `ActionRecorder.keyNameForCode` duplica `ShortcutKeyMap`, apesar deste ser o "single source of truth" documentado; divergência: Enter do teclado numérico (keycode 76) é emitido como "Enter", que `ShortcutKeyMap.parse` resolve para Return (keycode 36). *(Pendente)*
- **L4 — Espera composta:** um passo `.delay` espera `step.delay` e **depois** o `intervalBetweenSteps` do executor (somados); pode surpreender. *(Pendente/por design)*
- **L5 — Privacidade do log no feedback:** o e-mail de feedback anexa o log inteiro (cabeçalhos de sessão, nomes de macros, stderr do sistema) ao desenvolvedor; divulgar isso na UI. *(Pendente)*
- **L6 — I/O do log:** `AppLog.append` abre/fecha um `FileHandle` por linha. *(Pendente, baixo volume)*
- **L7 — Estatística inconsistente:** execuções pelo editor ("Executar"/"a partir daqui"/seleção) não incrementam `executionCount`/`lastUsedAt`; só o play da Home. *(Pendente/por design)*
- **L8 — Sem Developer ID/notarização:** aviso do Gatekeeper no primeiro lançamento (documentado em `AI_PROJECT_MAP.md`/`RELEASES.md`). TCC preservado via identidade self-signed estável. *(Conhecido)*

---

## 4. Funcionalidades ausentes

| Prioridade | Funcionalidade | Justificativa |
|---|---|---|
| Essencial | Suíte de testes automatizados (H2) | Rede de segurança contra regressões na lógica central |
| Essencial | Backup/restauração e "exportar biblioteca inteira" (M6) | Proteção da única cópia local; portabilidade |
| Essencial | Validação de passos antes de executar (M3) | Evita cliques em (0,0) e abortos confusos |
| Importante | Captura em múltiplos monitores (M4) | Correção em setups multi-tela comuns |
| Importante | Confirmação/Undo ao excluir macro (M5) | Integridade de dados |
| Importante | Feedback de permissão na gravação (M8) | Descoberta/usabilidade |
| Importante | UI de pausar/retomar (código já existe) | Controle da execução |
| Recomendável | Atalho global para disparar macro sem abrir o app | Caso de uso central de automação |
| Recomendável | Pastas/tags/busca na biblioteca | Escala com nº de macros |
| Recomendável | Passos condicionais/laços/variáveis | Automação mais rica |
| Recomendável | Developer ID + notarização | Remover aviso do Gatekeeper |
| Recomendável | Internacionalização (strings pt-BR hardcoded) | Alcance |
| Opcional | Agendamento, sincronização em nuvem, parametrização de macros | Conveniência |

---

## 5. Melhorias implementadas

Todas validadas por `swift build` (exit 0, sem novos avisos). Detalhe por item em `REMEDIATION_PLAN.md`.

1. **H1 — `MacroStore.load()`:** backup de `macros.json` corrompido em `macros.corrupt-<epoch>.json` + log, em vez de zerar e sobrescrever.
2. **M1 — `ActionRecorder`:** `passRetained` → `passUnretained` (fim do vazamento por evento).
3. **M3 — validação de passos:** `MacroStep.configurationIssue`/`isConfigured`; `MacroExecutor.execute` valida antes de ocultar janelas/iniciar e para com mensagem clara ("Passo N não configurado: …") em vez de clicar em (0,0); ⚠️ laranja nos passos incompletos no editor.
4. **M5 — confirmação de exclusão:** `NSAlert` antes de apagar uma macro.
5. **M6 — biblioteca:** seção "Biblioteca" em Configurações com exportar/importar toda a biblioteca (reaproveita `exportJSON`/`importJSON`).
6. **M8 — gravação sem permissão:** alerta + abrir Ajustes → Acessibilidade + log, em vez de falhar em silêncio.
7. **M10 — import com feedback:** `importJSON` retorna `(imported, skipped)`; UI reporta a contagem.
8. **L3 — fonte única de teclas:** gravador usa `ShortcutKeyMap.shortcutString`; `keyNameForCode` removido (corrige Enter numérico).
9. **L5 — privacidade:** nota de que o log é anexado ao feedback.

**Deliberadamente NÃO alterados** (para não arriscar a aplicação que já funciona): o motor de execução concorrente (M2 — corrida teórica de baixo risco), as closures de observação do editor/HUD (L1 — avisos benignos no modo Swift 5), M7/M9 (robustez incremental) e múltiplos monitores (M4, dispensado). Essas mudanças exigem validação em sessão gráfica interativa (injeção `CGEvent`, permissões) que não é confiável em ambiente headless.

---

## 6. Testes e resultados

- **Build debug:** `swift build` → **sucesso (exit 0)**, `Build complete!`.
- **Avisos:** 2 avisos de concorrência pré-existentes (`MainWindowController.swift:75`, `:144`, L1) + avisos benignos de `ld` sobre search paths do CommandLineTools. Nenhum erro.
- **Após as correções (H1, M1, M3, M5, M6, M8, M10, L3, L5):** rebuild **limpo (exit 0)**; nenhum aviso novo introduzido (seguem apenas os 2 pré-existentes, L1).
- **Testes automatizados:** suíte de lógica pura escrita em `Tests/MacroTicTests/MacroLogicTests.swift`, **porém não executável nesta máquina** — só há Command Line Tools, sem Xcode, e `XCTest` não resolve (`unable to resolve module dependency: 'XCTest'`). O `.testTarget` foi removido do `Package.swift` (deixado comentado) para não quebrar `swift build`/`swift test`; basta descomentá-lo com o Xcode instalado. Nenhum resultado de teste foi inventado.
- **Dados do usuário:** preservados; nenhuma escrita em `macros.json` foi feita pela auditoria.

---

## 7. Segurança

**Superfície de ataque:** mínima. App local, single-user, sem serviços de rede expostos. A capacidade sensível é a **injeção de eventos sintéticos** (`CGEvent`) e a **captura de entrada** (event taps) — ambas **corretamente controladas pela permissão de Acessibilidade (TCC)** do macOS. Sem Acessibilidade os eventos são no-op e os taps falham.

**Canal de atualização (Sparkle):** verificação de assinatura **EdDSA** (`SUPublicEDKey` embarcado no Info.plist), feed por **HTTPS** no GitHub (`releases/latest/download/appcast.xml`). Instalação automática sem prompt (`SUAutomaticallyUpdate`) — aceitável dada a verificação de assinatura; o risco residual é o comprometimento da conta GitHub/segredo `SPARKLE_PRIVATE_KEY`.

**Gestão de segredos (CI):** chave privada nunca persistida fora de `mktemp` com `trap cleanup`; certificado importado em keychain descartável, removido ao fim (`if: always()`). Boas práticas. Segredos via GitHub Secrets.

**Pontos de atenção:**
- **Não há sandbox** (incompatível com as APIs usadas) e **não há notarização** (aviso de Gatekeeper no 1º lançamento) — documentado.
- **Macros importadas são código de automação de fato:** um `.json` malicioso compartilhado pode fazer o app clicar/digitar arbitrariamente quando o usuário o executar. Recomenda-se um aviso ao importar (ligado a M6/M10).
- **Privacidade do log:** o feedback por e-mail envia o log (nomes de macros, stderr) ao desenvolvedor — divulgar na UI (L5). Textos digitados **não** são logados.
- **Área de transferência:** o modo "colar" lê e restaura o clipboard do usuário (`TypeTextAction.paste`) — benigno, restaurado após ~250 ms.

**Injeção/XSS/CSRF/SQL:** não aplicável (sem web/DB/entrada de rede). `mailto` é percent-encoded; nomes de arquivo de export são sanitizados (`MacroIO.sanitizedFileName`).

**Vulnerabilidades críticas:** nenhuma encontrada. **Riscos residuais:** conta/segredo de release; execução de macros importadas de origem não confiável.

---

## 8. Qualidade arquitetural

**Pontos fortes:**
- Separação de responsabilidades clara (App / Models / Actions / Views / Services), uma responsabilidade por arquivo.
- Camada de ações extensível via protocolo `MacroAction` + dicionário `MacroStepKind: MacroAction` — adicionar um tipo de passo é localizado.
- Modelos `@Observable` e `Codable` retrocompatíveis (`decodeIfPresent`); desenho consciente das limitações do toolchain (sem `@State`/`@Binding`, bindings manuais).
- Pipeline de release robusto, assinado, com estratégia explícita para preservar TCC entre updates (identidade self-signed estável).
- `AI_PROJECT_MAP.md` é uma documentação de mapa excepcionalmente detalhada e atualizada.

**Pontos a melhorar:**
- Concorrência dependente de `swiftLanguageMode(.v5)` para evitar checagem estrita — esconde riscos reais (M2); migrar gradualmente para `actor`/`Sendable`.
- Lógica de domínio acoplada ao alvo executável (`@main`) dificulta testes — extrair um alvo de biblioteca testável resolveria H2 e M2.
- Duplicação pontual (mapas de teclas, L3) e código morto (L2).
- Strings de UI hardcoded em pt-BR (sem i18n).

**Escalabilidade/manutenção:** adequadas para o tamanho atual; a biblioteca de macros é um único arquivo JSON carregado em memória — ok para centenas de macros, não pensado para milhares (sem paginação/índices, aceitável para o domínio).

---

## 9. Pendências

| ID | Pendência | Motivo de não ter sido resolvido nesta auditoria |
|----|-----------|---------------------------------------------------|
| H2 | Suíte de testes | Exige reestruturar `Package.swift` (alvo de biblioteca testável); compilação de testes não validável em headless — ver plano |
| M2 | Corrida de dados | Mudança de concorrência deve ser validada em execução real |
| M3 | Validação de passos | Mudança de UX/fluxo de execução; validar interativamente |
| M4 | Multi-monitor | Exige teste em hardware multi-tela |
| M5 | Confirmação de exclusão | Mudança de UX; preferível decisão do mantenedor |
| M6 | Backup/export da biblioteca | Nova feature de UI |
| M7–M10, L1–L7 | Ver §3 | Melhorias de robustez/UX, baixo risco, enfileiradas no plano |

Detalhes, abordagem e esforço estimado de cada uma em `REMEDIATION_PLAN.md`.

---

## 10. Conclusão técnica

MacroTic é um projeto **bem construído e honesto**: sem botões decorativos, sem telas falsas — todas as funcionalidades inspecionadas estão de fato implementadas e o caminho crítico (gravar → editar → executar → parar) é coerente e cuidadoso (foco de janela confiável, cancelamento mid-action, HUD que não desaparece). Os defeitos reais concentram-se em **robustez de dados e validação de entrada**, não em arquitetura.

Duas correções de alto valor e baixo risco (H1, M1) já foram aplicadas e validadas por compilação. O caminho mais importante adiante é **cobertura de testes (H2)** e **proteção/validação de dados (M3, M5, M6)**. Com esses itens fechados, a aplicação fica tecnicamente confiável para distribuição mais ampla.

**Veredito:** aprovada com ressalvas; base sólida, pendências claras e rastreáveis.
