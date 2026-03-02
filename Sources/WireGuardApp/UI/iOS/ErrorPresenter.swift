// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log

class ErrorPresenter: ErrorPresenterProtocol {
    static func showErrorAlert(
        title: String,
        message: String,
        from sourceVC: AnyObject? = nil,
        onPresented: (() -> Void)? = nil,
        onDismissal: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            let presentingVC: UIViewController? = {
                if let vc = sourceVC as? UIViewController {
                    return vc
                } else {
                    return topMostViewController()
                }
            }()

            guard let vc = presentingVC else {
                wg_log(.error, staticMessage: "ErrorPresenter: No view controller available to present alert.")
                return
            }

            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                onDismissal?()
            }
            alert.addAction(okAction)
            vc.present(alert, animated: true, completion: onPresented)
        }
    }

    private static func topMostViewController() -> UIViewController? {
        guard let keyWindow = UIApplication.shared
                .connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
            return nil
        }

        var topVC = keyWindow.rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}
