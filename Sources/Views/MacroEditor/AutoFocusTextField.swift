import AppKit
import SwiftUI

enum StepFocusRequest {
    static var pendingStepID: UUID?
}

struct AutoFocusTextField: NSViewRepresentable {
    let stepID: UUID
    let placeholder: String
    let text: Binding<String>

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.delegate = context.coordinator
        field.stringValue = text.wrappedValue

        if StepFocusRequest.pendingStepID == stepID {
            StepFocusRequest.pendingStepID = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak field] in
                guard let field, let window = field.window else { return }
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(field)
            }
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = text
        if field.stringValue != text.wrappedValue, field.currentEditor() == nil {
            field.stringValue = text.wrappedValue
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
