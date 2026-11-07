import SwiftUI

/// Apple-style, richly designed instruction manual for MacroTic.
/// Presented inline (state.selectedSection == .manual) with a header close button.
struct ManualView: View {
    let state: AppState
    let onClose: () -> Void

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                VStack(spacing: 30) {
                    hero
                    gettingStarted
                    accessibility
                    homeTour
                    createMacro
                    actionCatalog
                    recorder
                    tuning
                    running
                    favorites
                    advancedEditing
                    updates
                    troubleshooting
                    footer
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 28)
                .frame(maxWidth: 660)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(minWidth: 480, minHeight: 440)
        .background(.background)
    }

    // MARK: - Header

    private var toolbar: some View {
        HStack {
            Text("Manual de Instruções")
                .font(.title3.weight(.semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconActionButtonStyle())
            .help("Fechar o manual")
        }
        .padding(12)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)

            VStack(spacing: 6) {
                Text("Bem-vindo ao MacroTic")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Automatize qualquer tarefa repetitiva no seu Mac — cliques, textos, atalhos e janelas — e deixe o MacroTic fazer o trabalho por você.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Versão \(version)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Sections

    private var gettingStarted: some View {
        ManualSection(number: 1, icon: "sparkles", tint: .blue, title: "O que é o MacroTic") {
            ManualText("Uma macro é uma sequência de ações que o seu Mac executa sozinho, na ordem exata em que você definiu. Em vez de repetir o mesmo clique, texto ou atalho dezenas de vezes, você monta a sequência uma única vez e manda executar quantas vezes quiser.")
            ManualBullet(icon: "hand.tap", tint: .green, title: "Monte visualmente", text: "Adicione ações passo a passo, ou grave seus movimentos reais na tela.")
            ManualBullet(icon: "repeat", tint: .orange, title: "Repita sem esforço", text: "Defina o intervalo entre passos e o número de repetições.")
            ManualBullet(icon: "bolt.fill", tint: .purple, title: "Execute com um clique", text: "O MacroTic some da frente e faz tudo por você, mesmo sobre outros apps.")
        }
    }

    private var accessibility: some View {
        ManualSection(number: 2, icon: "lock.shield", tint: .pink, title: "Antes de começar: Acessibilidade") {
            ManualText("Para mover o cursor, clicar e digitar por você, o macOS exige que você autorize o MacroTic em Acessibilidade. Sem essa permissão, as macros não têm efeito.")
            Callout(icon: "exclamationmark.triangle.fill", tint: .orange,
                     text: "Na primeira execução, o macOS pode abrir essa tela automaticamente. Autorize e volte ao app.")
            NumberedSteps([
                "Abra Ajustes do Sistema › Privacidade e Segurança › Acessibilidade.",
                "Ative o interruptor ao lado de MacroTic.",
                "Se o app já estava aberto, não precisa reiniciar — a permissão passa a valer na próxima execução."
            ])
        }
    }

    private var homeTour: some View {
        ManualSection(number: 3, icon: "macwindow", tint: .teal, title: "A tela inicial") {
            ManualText("Tudo começa na tela inicial, onde ficam suas macros e os dois botões principais.")
            ManualBullet(icon: "plus.rectangle", tint: .blue, title: "Nova Macro", text: "Abre o editor para montar uma macro manualmente, ação por ação.")
            ManualBullet(icon: "record.circle", tint: .red, title: "Gravar Ações", text: "Captura seus cliques e teclas reais e os transforma em passos automaticamente.")
            ManualBullet(icon: "play.circle.fill", tint: .green, title: "Executar", text: "Cada macro na lista tem um botão de play para rodar na hora.")
            ManualBullet(icon: "star.fill", tint: .yellow, title: "Favoritar", text: "Marque as macros que você mais usa para encontrá-las rapidamente.")
            ManualBullet(icon: "questionmark.circle", tint: .gray, title: "Ajuda", text: "O ícone de interrogação abre este manual a qualquer momento.")
        }
    }

    private var createMacro: some View {
        ManualSection(number: 4, icon: "square.and.pencil", tint: .blue, title: "Criar uma macro manualmente") {
            NumberedSteps([
                "Toque em Nova Macro para abrir o editor.",
                "Dê um nome à macro e, se quiser, uma descrição.",
                "Toque em Adicionar ação e escolha o tipo de ação (veja o catálogo abaixo).",
                "Configure cada ação — posição do clique, texto, atalho, tempo de espera, etc.",
                "Ajuste o intervalo entre passos e quantas vezes repetir.",
                "Salve. Sua macro aparece na tela inicial, pronta para usar."
            ])
            Callout(icon: "keyboard", tint: .indigo,
                     text: "No editor: ⌘S salva sem fechar, ⌘R executa, ⌘W fecha, ⌘↑/⌘↓ reordenam o passo e ⌘⌫ exclui o passo selecionado.")
        }
    }

    private var actionCatalog: some View {
        ManualSection(number: 5, icon: "square.grid.2x2.fill", tint: .indigo, title: "Catálogo de ações") {
            ManualText("Cada passo de uma macro é uma destas ações. Combine-as livremente para reproduzir qualquer fluxo.")
            VStack(spacing: 10) {
                ForEach(MacroStepKind.allCases) { kind in
                    ActionCatalogRow(kind: kind, description: Self.description(for: kind))
                }
            }
        }
    }

    private static func description(for kind: MacroStepKind) -> String {
        switch kind {
        case .click: return "Clica numa posição exata da tela. Capture a posição apontando com o cursor."
        case .keyShortcut: return "Pressiona uma combinação de teclas, como ⌘C ou ⌘⇧4."
        case .typeText: return "Escreve um texto — tecla por tecla ou colando de uma vez."
        case .delay: return "Faz uma pausa pelo tempo que você definir, para a tela acompanhar."
        case .launchApp: return "Traz uma janela específica para a frente antes de continuar."
        case .dragAndDrop: return "Clica, arrasta de um ponto a outro e solta — ideal para mover itens."
        case .scroll: return "Rola a tela em qualquer direção, em linhas ou pixels."
        }
    }

    private var recorder: some View {
        ManualSection(number: 6, icon: "record.circle", tint: .red, title: "Gravar ações automaticamente") {
            ManualText("Não quer montar passo a passo? Deixe o MacroTic observar. Toque em Gravar Ações e faça os movimentos normalmente — cada clique e tecla vira um passo.")
            NumberedSteps([
                "Toque em Gravar Ações na tela inicial.",
                "Faça suas ações reais na tela (cliques, textos, atalhos).",
                "Toque em Parar Gravação quando terminar.",
                "O editor abre com todos os passos capturados, prontos para ajustar e salvar."
            ])
            Callout(icon: "wand.and.stars", tint: .purple,
                     text: "A gravação ignora o próprio clique no botão Parar, então a sequência fica limpa.")
        }
    }

    private var tuning: some View {
        ManualSection(number: 7, icon: "slider.horizontal.3", tint: .orange, title: "Ajustar a macro") {
            ManualBullet(icon: "textformat", tint: .blue, title: "Nome e descrição", text: "Identifique a macro e anote o que ela faz.")
            ManualBullet(icon: "timer", tint: .orange, title: "Intervalo", text: "O tempo de espera entre um passo e o próximo, para a interface acompanhar.")
            ManualBullet(icon: "repeat", tint: .green, title: "Repetir", text: "Quantas vezes a sequência inteira deve rodar em seguida.")
            ManualBullet(icon: "lock.fill", tint: .red, title: "Trava de segurança", text: "Bloqueie a edição para não alterar a macro por engano. Use Desbloquear para liberar.")
        }
    }

    private var running: some View {
        ManualSection(number: 8, icon: "play.fill", tint: .green, title: "Executar uma macro") {
            ManualText("Ao executar, o MacroTic some da frente para não atrapalhar e mostra um pequeno painel flutuante com o progresso. Ao terminar, o app volta e o cursor retorna à posição original.")
            ManualBullet(icon: "rectangle.on.rectangle", tint: .teal, title: "Painel de progresso", text: "Mostra o passo atual e a repetição, e fica visível por cima de qualquer app.")
            StopCallout()
            Callout(icon: "cursorarrow.motionlines", tint: .blue,
                     text: "Durante a execução o app fica oculto de propósito — isso é normal, não é uma falha. Ele reaparece no fim.")
        }
    }

    private var favorites: some View {
        ManualSection(number: 9, icon: "star.fill", tint: .yellow, title: "Favoritos") {
            ManualText("Marque com a estrela as macros que você usa com mais frequência. Elas ganham destaque na lista, ficando sempre à mão.")
        }
    }

    private var advancedEditing: some View {
        ManualSection(number: 10, icon: "wrench.and.screwdriver.fill", tint: .indigo, title: "Edição avançada") {
            ManualBullet(icon: "plus.square.on.square", tint: .blue, title: "Duplicar ação", text: "Copia um passo inteiro, com todos os seus ajustes, para repetir configurações rapidamente.")
            ManualBullet(icon: "forward.end.fill", tint: .green, title: "Executar a partir daqui", text: "Testa a macro começando de um passo específico, sem rodar os anteriores.")
            ManualBullet(icon: "arrow.up.arrow.down", tint: .orange, title: "Reordenar e excluir", text: "Use ⌘↑/⌘↓ para mover um passo e ⌘⌫ para removê-lo.")
        }
    }

    private var updates: some View {
        ManualSection(number: 11, icon: "arrow.down.circle.fill", tint: .blue, title: "Atualizações automáticas") {
            ManualText("O MacroTic verifica novas versões ao abrir e instala as atualizações para você. Uma janelinha mostra o progresso quando há algo novo.")
            Callout(icon: "gearshape.fill", tint: .gray,
                     text: "Em Configurações você vê a versão instalada, a última verificação e pode buscar atualizações manualmente.")
        }
    }

    private var troubleshooting: some View {
        ManualSection(number: 12, icon: "lifepreserver", tint: .pink, title: "Solução de problemas") {
            FAQRow(question: "A macro executa mas nada acontece.",
                   answer: "Falta a permissão de Acessibilidade. Autorize o MacroTic em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade.")
            FAQRow(question: "Os cliques caem no lugar errado.",
                   answer: "As posições são absolutas na tela. Recapture a posição do clique na mesma resolução e disposição de janelas que você vai usar.")
            FAQRow(question: "A macro vai rápido demais.",
                   answer: "Aumente o Intervalo entre passos para dar tempo da interface responder antes da próxima ação.")
            FAQRow(question: "O app sumiu durante a execução.",
                   answer: "É intencional: ele se esconde para não interferir e volta ao terminar. Use ⌘Esc para interromper a qualquer momento.")
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
            Text("Ainda com dúvidas?")
                .font(.headline)
            Button {
                FeedbackMailer.compose()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                    Text("Falar com o desenvolvedor")
                }
            }
            Text("MacroTic · Versão \(version) · por Robert Ruas")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

// MARK: - Reusable building blocks

private struct ManualSection<Content: View>: View {
    var number: Int? = nil
    let icon: String
    let tint: Color
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                if let number {
                    Text("\(number). \(title)")
                        .font(.title3.weight(.semibold))
                } else {
                    Text(title)
                        .font(.title3.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ManualText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ManualBullet: View {
    let icon: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ActionCatalogRow: View {
    let kind: MacroStepKind
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(kind.tint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: kind.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(kind.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(.callout.weight(.semibold))
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct NumberedSteps: View {
    let steps: [String]
    init(_ steps: [String]) { self.steps = steps }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor, in: Circle())
                    Text(step)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct Callout: View {
    let icon: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 20)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

/// Dedicated callout explaining the ⌘Esc stop shortcut with key caps.
private struct StopCallout: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 22, height: 20)
            Text("Pare a qualquer momento com")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                KeyCap("⌘")
                KeyCap("Esc")
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct KeyCap: View {
    let label: String
    init(_ label: String) { self.label = label }
    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            )
    }
}

private struct FAQRow: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(question).font(.callout.weight(.semibold))
            }
            Text(answer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
