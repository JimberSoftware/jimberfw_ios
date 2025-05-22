import UIKit

/// Utility to prompt the user for a new tunnel name via a UIAlertController.
/// Call from any UIViewController.
public extension UIViewController {
    /// Presents an alert to enter a tunnel name, validated only on submission (5–30 chars).
    /// - Parameter completion: called with the valid name or nil if cancelled.
    func presentTunnelNamePrompt(
        completion: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(
            title: "New Daemon",
            message: "Enter a name for your daemon",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Daemon name"
        }

        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(nil)
        }
        alert.addAction(cancelAction)

        // Create action with validation on submit
        let createAction = UIAlertAction(title: "Create", style: .default) { _ in
            let rawText = alert.textFields?.first?.text ?? ""
            let name = rawText.trimmingCharacters(in: .whitespaces)
            if (1...256).contains(name.count) {
                completion(name)
            } else {
                // Show error and re-present prompt
                let errorAlert = UIAlertController(
                    title: "Invalid Name",
                    message: "Invalid daemon name",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    self.presentTunnelNamePrompt(completion: completion)
                })
                self.present(errorAlert, animated: true)
            }
        }
        alert.addAction(createAction)

        self.present(alert, animated: true)
    }

    /// Async wrapper around `presentTunnelNamePrompt`.
    /// Suspends until the user provides a valid name or cancels (returns nil on cancel).
    func promptTunnelNameAsync() async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            self.presentTunnelNamePrompt { name in
                continuation.resume(returning: name)
            }
        }
    }
}
