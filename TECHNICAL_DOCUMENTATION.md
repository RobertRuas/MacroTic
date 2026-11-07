# MacroTic — Documentação Técnica

> Referência técnica completa para desenvolvedores que vão manter e evoluir o MacroTic.
> Complementa `AI_PROJECT_MAP.md` (mapa arquivo-a-arquivo) e `RELEASES.md` (processo de release).
> Atualizada em: 2026-11-07.

---

## 1. Visão geral e finalidade

MacroTic é um aplicativo **nativo de macOS** para **automação de macros de interface**: o usuário monta (ou grava) uma sequência de ações — cliques, digitação, atalhos de teclado, esperas, foco de janela, arrasto-e-solta e scroll — e a reproduz sob demanda. As ações são injetadas no nível do sistema via **Core Graphics Events (`CGEvent`)** e a gravação usa **event taps** da Accessibility API. A biblioteca de macros é persistida localmente em JSON. Há auto-atualização via **Sparkle**.

Público-alvo: usuários de macOS que querem automatizar tarefas repetitivas de GUI. Idioma da interface: português (pt-BR).

## 2. Arquitetura e tecnologias

| Camada | Tecnologia |
|---|---|
| Linguagem | Swift (toolchain 6.2, `swiftLanguageMode(.v5)`) |
| UI | SwiftUI renderizando dentro de `NSWindow`/`NSPanel` (AppKit), via `NSHostingView` |
| Estado | `@Observable` (ObservationMacros). Sem `@State`/`@Binding`/`@Environment` (SwiftUIMacros indisponível no Command Line Tools) — bindings manuais com `Binding(get:set:)` |
| Automação | `CGEvent` (HID/session tap) para injeção; event taps `listenOnly`/`defaultTap` para captura e para o atalho de cancelamento |
| Janelas de terceiros | Accessibility API (`AXUIElement`) para listar/focar janelas |
| Persistência | JSON `Codable` (ISO-8601) em Application Support |
| Atualização | Sparkle 2.6.4+ (SPUUpdater custom + user driver silencioso) |
| Build | Swift Package Manager (sem projeto Xcode) |
| CI/Release | GitHub Actions (`.github/workflows/release.yml`) |

**Padrão geral:** AppKit controla o ciclo de vida e as janelas (`MacroTicApp` → `AppDelegate` → `MainWindowController`); SwiftUI desenha o conteúdo; a lógica vive em classes `@Observable` (Models) e numa camada de ações plugável (`MacroAction`).

**Política de ativação:** `.regular` (ícone no Dock). Fechar a janela encerra o app — exceto durante uma execução (as janelas são ocultadas de propósito e só o HUD fica; ver `AppDelegate.applicationShouldTerminateAfterLastWindowClosed`).

## 3. Estrutura de diretórios

```
MacroTic/
├── Package.swift            Manifesto SPM (alvo executável único "MacroTic", dep. Sparkle, rpaths)
├── Package.resolved         Pin da versão do Sparkle
├── dev.sh                   Hot reload (fswatch → build → relaunch)
├── AI_PROJECT_MAP.md        Mapa arquivo-a-arquivo (fonte de verdade da estrutura)
├── RELEASES.md              Guia de release e auto-update
├── AUDIT_REPORT.md          Relatório de auditoria técnica
├── TECHNICAL_DOCUMENTATION.md  Este documento
├── REMEDIATION_PLAN.md      Plano de correções e pendências
├── Packaging/               Info.plist (template), AppIcon.icns, AppIcon-1024.png
├── Scripts/                 package_app.sh, build_appcast.sh, generate_sparkle_keys.sh
├── .github/workflows/       release.yml
└── Sources/
    ├── App/                 Ciclo de vida, janelas, updater (5 arquivos)
    ├── Models/              Estado, domínio, execução, gravação, persistência (12 arquivos)
    │   └── Actions/         Implementações de MacroAction (8 arquivos)
    ├── Views/               SwiftUI (Home, MacroEditor, Manual, Settings, Components)
    └── Services/            AppLog, FeedbackMailer
```

Para o propósito exato de cada arquivo, consulte `AI_PROJECT_MAP.md`.

## 4. Módulos e componentes

- **App:** `MacroTicApp` (`@main`), `AppDelegate` (bootstrap de log, permissão de Acessibilidade, política de término), `MainWindowController` (janela principal + toolbar + janela do editor + HUD de execução + observações de estado), `UpdaterController`/`SilentUpdateUserDriver`/`UpdateProgressWindow` (Sparkle).
- **Estado:** `AppState` (raiz; dono de `MacroStore`, `MacroExecutor`, `ActionRecorder`, `UpdaterController` e do `MacroDraft` do editor).
- **Domínio:** `Macro`, `MacroStep`, `MacroStepKind`, `MacroDraft`, enums (`ScrollDirection`, `ScrollUnit`, `TextInputMode`).
- **Execução:** `MacroExecutor` + `Actions/*` (cada tipo de passo).
- **Captura:** `ActionRecorder`; pickers interativos (`ScreenCoordinatePicker`, `ShortcutCapturePicker`, `ScrollCapturePicker`).
- **Serviços de SO:** `WindowCatalog` (AX), `ShortcutKeyMap` (keycodes), `MacroStore`/`MacroIO` (persistência/IO), `AppLog`, `FeedbackMailer`.
- **Views:** `HomeView`+lista/linha/cards; `CreateMacroView`+`MacroStepRowView`+overlays; `ManualView`; `SettingsView`; componentes.

## 5. Funcionalidades (descrição)

1. **Criar/Editar macro** — editor em janela dedicada (`CreateMacroView`): identidade (nome/descrição/ícone), barra de execução (intervalo ms, repetições), lista de ações com edição inline por tipo, seleção múltipla, reordenação (arrastar e ⌘↑/⌘↓), execução parcial/por seleção, trava de segurança, modo depuração, import/export de 1 macro. Impede nomes duplicados.
2. **Gravar ações** — `ActionRecorder` captura cliques, teclas e scroll via event tap; coalesce digitação, ignora auto-repeat, trata Backspace, mescla scrolls do mesmo sentido, ignora cliques nas próprias janelas. Ao parar (na Home) abre o editor com os passos; no editor, anexa ao draft.
3. **Executar** — `MacroExecutor` roda a sequência em `Task.detached`, repetindo `repeatCount` vezes com `intervalBetweenSteps` entre passos; oculta as janelas e mostra um HUD; restaura cursor e traz o app de volta ao fim.
4. **Parar** — botão "Parar" (Home/HUD/editor) e **⌘Esc global** (event tap de sessão) durante a execução.
5. **Favoritos** — estrela por macro; favoritos aparecem primeiro (`MacroStore.sorted`).
6. **Atualização** — checagem no launch (janelinha de progresso) + verificação manual em Configurações.
7. **Feedback/Logs** — e-mail ao desenvolvedor com o log anexado.

## 6. Fluxos de navegação e regras de negócio

- **Navegação:** janela única com uma toolbar nativa; `state.selectedSection` alterna Home/Configurações; `.manual` abre o Manual; o editor é uma **janela separada** (`MainWindowController` observa `state.isCreatingMacro`).
- **Fechar o app:** permitido direto só na Home; em outras telas, confirma via `NSAlert`; nunca encerra durante execução.
- **Salvar:** `AppState.saveMacro` — ao criar, adota o id salvo como `editingMacroID` (evita duplicar em saves repetidos); ao editar, preserva `createdAt`/`lastUsedAt`/`executionCount` e `isFavorite` do original.
- **Executar (regras):** ignora segundo play se já rodando; só conta uso (`markUsed`) quando a Acessibilidade está concedida; execução parcial (`startAt>0`) é passagem única; execução completa honra `repeatCount`.
- **Trava:** `editingLocked = draft.isLocked || executor.isRunning` desabilita toda edição; executar auto-trava e reverte ao fim.

## 7. Funções/métodos e serviços importantes

- `MacroExecutor.execute(_:startAt:)` — orquestra; checa `AXIsProcessTrusted()`; instala o tap de ⌘Esc; loop repetição×passo; delega a `MacroAction.execute(step:)`; trata passo desconhecido/falha; restaura cursor; reativa o app. `stop()/pause()/resume()` (pause/resume sem UI — ver auditoria L2).
- `MacroAction.execute(step:) async -> Bool` — contrato de cada ação; retorna `false` para abortar. Ações cooperam com `Task.isCancelled` frame a frame.
- `ActionRecorder.handleEvent/handleKeyDown/handleScroll` — lógica "smart" de captura/coalescência; `makeDraft()`.
- `ShortcutKeyMap.parse(_:)` — string de atalho → `(keyCode, flags)`, aceitando símbolos (⌘⇧) e palavras legadas (cmd+, ctrl+) e `KeyNNN`.
- `MacroStore` — `save/delete/markUsed/toggleFavorite/sorted/exportJSON/importJSON/exportURL`; `load()` com **backup de arquivo corrompido** (salvaguarda de dados); `persist()` atômico.
- `WindowCatalog` — `windows()/titles()/window(forTitle:)/frame(forTitle:)` via AX.
- `AppLog` — logger persistente com tee de stderr e truncamento; `FeedbackMailer.compose()` com anexo de log (fallback mailto inline).

## 8. Modelagem de dados (persistência)

Não há banco de dados relacional. O armazenamento é **documento JSON** único.

**`Macro`** (`Codable`, decode customizado retrocompatível): `id: UUID`, `name`, `details`, `iconName`, `steps: [MacroStep]`, `intervalBetweenSteps: Double` (default 0.5), `repeatCount: Int` (≥1), `createdAt: Date`, `lastUsedAt: Date?`, `executionCount: Int`, `isFavorite: Bool`, `isLocked: Bool`.
Passos indecodificáveis são descartados (`LossyStep`) — ver auditoria M7.

**`MacroStep`** (`Codable`, decode com `decodeIfPresent`): `id`, `kind: MacroStepKind`, `value`, `delay`, coordenadas de clique (`clickX/Y`), de arrasto (`dragStart/EndX/Y`), de scroll (`scrollDirection/Amount/MovesMouse/X/Y/Unit/StepDelayMs`) e `textMode`.

**`MacroStepKind`**: `keyShortcut, typeText, click, delay, launchApp, dragAndDrop, scroll` (o legado `openURL` foi removido; passos antigos são descartados no load).

## 9. Relacionamentos e estrutura de armazenamento

- `AppState` **1—1** com `MacroStore`, `MacroExecutor`, `ActionRecorder`, `UpdaterController`; **1—1** com o `MacroDraft` do editor.
- `MacroStore` **1—N** `Macro`; `Macro` **1—N** `MacroStep` (composição; passos embutidos no JSON da macro).
- `MacroExecutor` **usa** `[MacroStepKind: MacroAction]` (estratégia por tipo).
- **Localização em disco:**
  - Biblioteca: `~/Library/Application Support/MacroTic/macros.json`
  - Backup de corrupção: `~/Library/Application Support/MacroTic/macros.corrupt-<epoch>.json`
  - Log: `~/Library/Logs/MacroTic/MacroTic.log`
- **Serialização:** `JSONEncoder` com `.prettyPrinted, .sortedKeys`, datas ISO-8601; escrita atômica (`.atomic`).

## 10. APIs e integrações

Sem APIs de rede próprias. Integrações de sistema:
- **Core Graphics Events** — injeção/captura de teclado, mouse, scroll (HID/session taps).
- **Accessibility (AX)** — listar/focar janelas de terceiros; requisito de permissão TCC.
- **AppKit** — janelas, painéis, `NSSharingService` (e-mail), `NSSavePanel/NSOpenPanel`, `NSPasteboard`, `NSWorkspace`.
- **Sparkle** — appcast por HTTPS no GitHub Releases; verificação EdDSA.

## 11. Autenticação e permissões

Não há autenticação de usuário. A única permissão é a **Acessibilidade (TCC)** do macOS:
- Solicitada no launch (`AXIsProcessTrustedWithOptions(prompt:true)`).
- Requerida para injetar eventos (execução) e para os event taps (gravação, ⌘Esc, pickers de captura).
- Sem ela: a execução entra em `.error` com instrução e abre Ajustes → Privacidade e Segurança → Acessibilidade; a gravação atualmente falha em silêncio (auditoria M8).
- Preservação do grant entre updates: identidade de assinatura **self-signed estável** (não ad-hoc), para o *designated requirement* não mudar.

## 12. Estratégias de segurança

Resumo (detalhe em `AUDIT_REPORT.md` §7): superfície local mínima; capacidade sensível (injeção/captura) gated por TCC; updates verificados por EdDSA sobre HTTPS; segredos de CI em keychain descartável com cleanup. Sem sandbox/notarização (conhecido). Atenção: macros importadas são código de automação de fato (avisar na importação); log anexado ao feedback (divulgar).

## 13. Gerenciamento de erros e logs

- **Erros de execução:** `MacroExecutor` registra em `AppLog.error(...)` nos três pontos de falha (Acessibilidade negada, ação desconhecida, passo falho) e reflete em `state = .error(...)`, exibido na UI.
- **Logging:** `AppLog` escreve em `~/Library/Logs/MacroTic/MacroTic.log`, faz **tee** do stderr (captura `NSLog`/`print`/erros do sistema) e trunca para ~256 KB em limite de linha. `bootstrap()` chamado cedo no `AppDelegate`.
- **Persistência:** falhas de escrita/leitura são toleradas (`try?`); leitura corrompida agora gera **backup** em vez de perda (auditoria H1, corrigido).

## 14. Estratégia de testes

**Estado atual:** uma suíte de testes de lógica pura existe em `Tests/MacroTicTests/MacroLogicTests.swift` (parse de atalhos, decode retrocompatível + descarte lossy, `MacroStep.configurationIssue`, seleção/reordenação de `MacroDraft`). Ela **não está ativa** no `Package.swift` porque esta máquina só tem os Command Line Tools e `XCTest` não está disponível — com o Xcode instalado, descomente o `.testTarget` no `Package.swift` e rode `swift test`. Os testes **não** instanciam `MacroStore` (que mexe no `macros.json` real). **Plano** (ver `REMEDIATION_PLAN.md`): extrair a lógica de domínio para um alvo de biblioteca testável e cobrir funções puras determinísticas:
- `ShortcutKeyMap.parse` (símbolos, palavras legadas, `KeyNNN`, Enter/numpad).
- `Macro`/`MacroStep` decode retrocompatível e descarte de passos desconhecidos.
- `MacroStore`: `sorted` (favoritos primeiro, ordem preservada), dedup em `importJSON`, e o **backup de corrupção** de `load()`.
- `MacroDraft`: `moveSelectedUp/Down` (blocos contíguos), `move(before:)`, seleção.
- `ActionRecorder`: coalescência de digitação/scroll, Backspace (via injeção de `MacroStep`).
A automação `CGEvent`/multi-monitor exige testes manuais em sessão gráfica (checklist no plano).

## 15. Instalação e configuração do ambiente

**Requisitos:** macOS 26+; Xcode Command Line Tools (toolchain Swift 6.2); `fswatch` (opcional, hot reload) via Homebrew; `jq` (usado pelo `build_appcast.sh`).
**Clonar e compilar:**
```bash
git clone <repo> && cd MacroTic
swift build                 # debug
.build/debug/MacroTic       # executa
bash dev.sh                 # hot reload (watch + rebuild + relaunch)
```
**Permissão:** conceder Acessibilidade ao binário/app em Ajustes do Sistema → Privacidade e Segurança → Acessibilidade (o app solicita no primeiro launch).

## 16. Variáveis de ambiente

Apenas no empacotamento/release (não em runtime):
- `Scripts/package_app.sh`: `APP_VERSION` (obrigatória), `APP_OWNER`, `APP_REPO`, `SPARKLE_PUBLIC_KEY`, `CODESIGN_IDENTITY` (fallback ad-hoc `-`).
- `Scripts/build_appcast.sh`: `SPARKLE_PRIVATE_KEY` (obrigatória).
- CI (`release.yml`) injeta via GitHub Secrets: `SPARKLE_PRIVATE_KEY`, `SPARKLE_PUBLIC_KEY`, `CODESIGN_P12_BASE64`, `CODESIGN_P12_PASSWORD`, `CODESIGN_IDENTITY`.

## 17. Processo de desenvolvimento e execução

- Uma responsabilidade por arquivo; Views em `Views/`, modelos observáveis em `Models/`; sem comentários no código (o mapa é a referência).
- **Após mudanças estruturais** (criar/mover/renomear/apagar arquivo), atualizar `AI_PROJECT_MAP.md`.
- Hot reload com `dev.sh` (mata instância anterior, recompila, relança a cada mudança em `Sources/`).

## 18. Processo de build e publicação

Disparado por push de tag `v*.*.*` (`release.yml`): resolve deps → `swift build -c release` → importa certificado em keychain descartável → `package_app.sh` (monta `.app`, embute `Sparkle.framework`, preenche Info.plist, assina profundamente, zipa em `dist/`) → `build_appcast.sh` (baixa CLI Sparkle da versão pinada, assina o zip com EdDSA, gera `appcast.xml`) → cria o GitHub Release com `.zip`+`appcast.xml` → apaga releases antigos (mantém só o mais novo) → remove a keychain. O feed estático aponta sempre para `releases/latest/download/appcast.xml`. Passo-a-passo manual em `RELEASES.md` e em `CLAUDE.md`.

## 19. Backup, recuperação e manutenção

- **Backup atual:** manual — exportar macro a macro pelo editor (`MacroIO`). Não há "exportar biblioteca" (auditoria M6).
- **Recuperação de corrupção:** `load()` preserva `macros.corrupt-<epoch>.json` quando o JSON não decodifica; copiar/corrigir e restaurar como `macros.json`.
- **Logs:** autolimitados a ~256 KB; local em `~/Library/Logs/MacroTic/`.
- **Manutenção:** manter `Package.resolved` e `AI_PROJECT_MAP.md` sincronizados; rotacionar as chaves Sparkle/segredos conforme política.

## 20. Limitações conhecidas e recomendações futuras

**Limitações:** sem testes automatizados (H2); captura de coordenadas limitada à tela principal (M4); passos "Selecionar janela" dependem do título vivo (M9); exclusão sem confirmação/undo (M5); sem backup/export da biblioteca (M6); macros usam coordenadas absolutas (não independentes de resolução/arranjo de telas); UI só em pt-BR; sem Developer ID/notarização (aviso do Gatekeeper); pausar/retomar sem UI; corrida de dados teórica nas flags de controle (M2).

**Recomendações (prioridade):** 1) testes + alvo de biblioteca; 2) validação de passos (M3) e confirmação de exclusão (M5); 3) backup/export da biblioteca (M6) e feedback de permissão na gravação (M8); 4) suporte multi-monitor (M4); 5) notarização; 6) i18n; 7) atalho global de disparo e organização da biblioteca (pastas/busca). Detalhes em `REMEDIATION_PLAN.md`.
