# MacroTic — Plano de Correções e Pendências

> Plano acionável derivado de `AUDIT_REPORT.md`. Cada item: abordagem, arquivos, esforço, risco e situação.
> Legenda situação: ✅ Feito · 🔧 Pronto para implementar · 🧪 Requer validação interativa · 📋 Decisão do mantenedor.
> Esforço: P (≤1h) · M (meio dia) · G (1–3 dias).

---

## Já implementado ✅ (tudo validado por `swift build` exit 0, sem novos avisos)

### H1 — Backup de `macros.json` corrompido  ✅ `MacroStore.load()`
Falha de decode com dados não vazios agora grava `macros.corrupt-<epoch>.json` e loga, em vez de zerar e permitir sobrescrita.

### M1 — Vazamento de retain na gravação  ✅ `ActionRecorder.swift`
`passRetained` → `passUnretained` (consistente com os demais taps). Retorno é ignorado em taps `listenOnly`, sem mudança de comportamento.

### M3 — Validação de passos antes de executar  ✅ `MacroStep`, `MacroExecutor`, `MacroStepRowView`
Novo `MacroStep.configurationIssue`/`isConfigured`. `MacroExecutor.execute` valida os passos que vão rodar **antes** de ocultar janelas/iniciar; um passo incompleto para com mensagem clara ("Passo N não configurado: …") em vez de clicar em (0,0) ou falhar genericamente. O editor mostra um ⚠️ laranja (com tooltip) nos passos incompletos. Não afeta macros válidas.

### M5 — Confirmação ao excluir macro  ✅ `AppState.deleteMacro`
`NSAlert` de confirmação (Cancelar padrão, Apagar destrutivo) antes de remover. Mesmo estilo da confirmação de fechar a janela.

### M6 — Backup/exportação/importação da biblioteca  ✅ `SettingsView`, `MacroStore`
Nova seção "Biblioteca" em Configurações com "Exportar biblioteca…" (`NSSavePanel`) e "Importar biblioteca…" (`NSOpenPanel`), usando os métodos antes órfãos (`exportJSON`/`importJSON`). Resolve também o código morto (L2 parcial).

### M8 — Feedback de permissão ao gravar  ✅ `ActionRecorder.startRecording`
Se o event tap não puder ser criado (sem Acessibilidade), agora exibe `NSAlert`, (re)solicita a permissão e abre Ajustes → Acessibilidade, além de logar — espelhando o `MacroExecutor`.

### M10 — Feedback na colisão de id ao importar  ✅ `MacroStore.importJSON`
`importJSON` passou a retornar `(imported, skipped)`; a importação de biblioteca mostra "X importada(s); Y já existente(s) ignorada(s)".

### L3 — Fonte única de teclas no gravador  ✅ `ActionRecorder`
`handleKeyDown` agora gera o atalho via `ShortcutKeyMap.shortcutString` (formato canônico idêntico ao do picker) e `keyNameForCode` foi removido — elimina a duplicação e a divergência do Enter numérico (76).

### L5 — Aviso de privacidade do log  ✅ `SettingsView`
Nota abaixo do botão de feedback informando que o log recente é anexado ao e-mail.

---

## Prioridade 1 — Essencial

### H2 — Suíte de testes automatizados  🧪 BLOQUEADO NESTE AMBIENTE · Esforço G
**Situação:** a suíte foi **escrita** em `Tests/MacroTicTests/MacroLogicTests.swift` (testes puros de `ShortcutKeyMap.parse`, decode retrocompatível + descarte lossy, `MacroStep.configurationIssue`, seleção/reordenação de `MacroDraft`). Porém **não foi possível executar nem manter o alvo de teste ativo**: esta máquina tem apenas os **Command Line Tools**, sem Xcode completo, e `XCTest` não está disponível (`unable to resolve module dependency: 'XCTest'`). Por isso o `.testTarget` foi **removido do `Package.swift`** (deixado comentado) para não quebrar `swift build`/`swift test`.
**Para ativar (com Xcode instalado):** descomentar o `.testTarget` no `Package.swift` e rodar `swift test` (ou `xcodebuild test`). Deliberadamente **não** instanciam `MacroStore` (que lê/escreve o `macros.json` real).
**Evolução recomendada:** extrair a lógica de domínio para um alvo de **biblioteca** (`MacroTicCore`) para desacoplar de AppKit/`@main` e permitir CI de testes.

---

## Prioridade 2 — Importante

### M4 — Múltiplos monitores  ❌ DISPENSADO pelo usuário (não utiliza múltiplos monitores).

### Pausar/Retomar na UI (ativa código existente)  🔧 · Esforço P · Risco baixo
`MacroExecutor.pause()/resume()` já existem (L2). Expor um botão no HUD/editor. **Arquivos:** `ExecutionHUDView.swift`, `MainWindowController.swift`.

---

## Prioridade 3 — Robustez / correção

### M2 — Corrida de dados nas flags de controle  🧪 · Esforço M · Risco médio
**Abordagem:** confiar apenas em `Task.isCancelled` para parada (as ações já cooperam) e/ou mover `shouldStop`/`isPaused` para um `actor` ou `OSAllocatedUnfairLock`. **Arquivos:** `MacroExecutor.swift`. **Validar** em execução real que ⌘Esc e o botão continuam interrompendo mid-action.

### M7 — Perda silenciosa de passos desconhecidos  🔧 · Esforço M · Risco baixo
**Abordagem:** `LossyStep` registrar/contar passos descartados e avisar o usuário ao abrir/salvar uma macro afetada; considerar preservar o JSON bruto desconhecido. **Arquivos:** `Macro.swift`, `MacroStore.swift`, UI do editor.

### M9 — Robustez do passo "Selecionar janela"  🔧 · Esforço M · Risco baixo
**Abordagem:** guardar app (bundle id) + padrão de título (parcial/regex) além do título exato; fallback para a primeira janela do app-alvo em vez de falhar. **Arquivos:** `MacroStep.swift`, `FocusWindowAction.swift`, `WindowCatalog.swift`, `MacroStepRowView.windowEditor`.

---

## Prioridade 4 — Baixas / limpeza

| ID | Item | Abordagem | Arquivos | Esforço |
|----|------|-----------|----------|---------|
| L1 | Avisos de concorrência | **Mantido como está** — closures `onChange` que dirigem o editor/HUD (comportamento crítico que já funciona); avisos benignos no modo Swift 5. Não tocado para não arriscar. Fix futuro: `MainActor.assumeIsolated`/wrapper `Sendable` | `MainWindowController.swift:73,142` | P |
| L2 | Código morto | ✅ Parcial: `exportJSON/importJSON` agora ligados (M6). Resta decidir sobre `pause()/resume()` (manter para UI futura ou remover) | `MacroExecutor.swift` | P |
| L3 | Mapa de teclas duplicado | ✅ Feito: gravador usa `ShortcutKeyMap.shortcutString`; `keyNameForCode` removido | — | — |
| L4 | Espera composta delay+intervalo | Documentar no Manual ou não aplicar `intervalBetweenSteps` após passo `.delay` | `MacroExecutor.swift`, `ManualView.swift` | P |
| L5 | Privacidade do log no feedback | ✅ Feito: nota na UI (Configurações) | — | — |
| L6 | I/O do log por linha | Manter um `FileHandle` aberto na `queue` em vez de abrir/fechar por linha | `AppLog.swift` | P |
| L7 | Estatística de uso inconsistente | Decidir se execuções pelo editor contam uso; alinhar `markUsed` | `AppState.swift`, `MainWindowController.EditorRoot` | P |
| L8 | Developer ID/notarização | Adicionar conta Apple Developer, notarizar no `release.yml` | `release.yml`, `package_app.sh` | M |

---

## Checklist de validação manual (sessão gráfica, com Acessibilidade concedida)

Itens que não puderam ser validados em headless e devem ser exercitados após qualquer mudança em automação:
1. Gravar → parar → editar → salvar → executar uma macro de clique+digitação; conferir resultado no app-alvo.
2. ⌘Esc e botão "Parar" interrompem no meio de um clique/arrasto/scroll/digitação longos.
3. Repetição (`repeatCount`) e `intervalBetweenSteps` respeitados; cursor restaurado; app volta à frente ao fim.
4. HUD visível sobre o app automatizado, inclusive em tela cheia; app não encerra mid-run.
5. Foco de janela traz a janela correta à frente (e o fallback quando o título mudou).
6. Captura de coordenadas/scroll na tela principal e (após M4) em telas secundárias.
7. Auto-update: num `.app` empacotado/assinado, a janelinha de progresso e a instalação silenciosa funcionam; grant de Acessibilidade sobrevive ao update.

## Sequência sugerida (restante)
Instalar Xcode e ativar H2 (testes) → M2 → M7 → M9 → L2/L4/L6/L7 → L8 (notarização). M4 dispensado; passos condicionais dispensados pelo usuário por ora. Cada mudança com rebuild + checklist manual quando tocar automação.
