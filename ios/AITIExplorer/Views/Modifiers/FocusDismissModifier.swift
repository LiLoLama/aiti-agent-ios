import SwiftUI
import UIKit

private struct FocusDismissModifier: ViewModifier {
    let dismissAction: () -> Void

    func body(content: Content) -> some View {
        content
            .background(FocusDismissBackground(dismissAction: dismissAction))
    }
}

private struct FocusDismissBackground: UIViewRepresentable {
    let dismissAction: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(dismissAction: dismissAction)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.dismissAction = dismissAction
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var dismissAction: () -> Void

        init(dismissAction: @escaping () -> Void) {
            self.dismissAction = dismissAction
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            dismissAction()
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            if translation.y > 16 {
                dismissAction()
                gesture.setTranslation(.zero, in: gesture.view)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

extension View {
    func dismissFocusOnInteract<Value: Hashable>(_ focus: FocusState<Value?>.Binding) -> some View {
        modifier(FocusDismissModifier {
            focus.wrappedValue = nil
        })
    }

    func dismissFocusOnInteract(_ focus: FocusState<Bool>.Binding) -> some View {
        modifier(FocusDismissModifier {
            focus.wrappedValue = false
        })
    }
}
