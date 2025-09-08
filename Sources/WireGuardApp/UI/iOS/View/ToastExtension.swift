// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

extension UIViewController {
    func showToast(message: String, position: String = "bottom") {
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textAlignment = .center
        toastLabel.textColor = .white
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        toastLabel.numberOfLines = 0
        toastLabel.translatesAutoresizingMaskIntoConstraints = false

        let toastContainer = UIView()
        toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastContainer.layer.cornerRadius = 10
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.clipsToBounds = true

        toastContainer.addSubview(toastLabel)
        self.view.addSubview(toastContainer)

        // Label constraints inside container
        NSLayoutConstraint.activate([
            toastLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 10),
            toastLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -10),
            toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 15),
            toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -15),
        ])

        // Toast container position on screen
        NSLayoutConstraint.activate([
            toastContainer.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            toastContainer.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 20),
            toastContainer.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -20)
        ])

        if position.lowercased() == "top" {
            toastContainer.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 50).isActive = true
        } else {
            toastContainer.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -50).isActive = true
        }

        // Initial state
        toastContainer.alpha = 0.0

        // Animate in and out
        UIView.animate(withDuration: 0.3, animations: {
            toastContainer.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseInOut, animations: {
                toastContainer.alpha = 0.0
            }) { _ in
                toastContainer.removeFromSuperview()
            }
        }
    }
}
