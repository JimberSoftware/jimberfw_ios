// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class MainViewController: UISplitViewController {

    var tunnelsManager: TunnelsManager?
    var onTunnelsManagerReady: ((TunnelsManager) -> Void)?
    var tunnelsListVC: TunnelsListTableViewController?

    init() {
        let detailVC = UIViewController()
        detailVC.view.backgroundColor = .systemBackground
        let detailNC = UINavigationController(rootViewController: detailVC)

        let masterVC = TunnelsListTableViewController()
        let masterNC = UINavigationController(rootViewController: masterVC)

        tunnelsListVC = masterVC

        super.init(nibName: nil, bundle: nil)

        viewControllers = [ masterNC, detailNC ]

        restorationIdentifier = "MainVC"
        masterNC.restorationIdentifier = "MasterNC"
        detailNC.restorationIdentifier = "DetailNC"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        delegate = self

        // On iPad, always show both masterVC and detailVC, even in portrait mode, like the Settings app
        preferredDisplayMode = .allVisible

        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                wg_log(.error, message: "Error when creating tunnelmanager: \(error)")

                let signInVc = SignInViewController()
                self.showDetailViewController(signInVc, sender: self)

            case .success(let tunnelsManager):
                self.tunnelsManager = tunnelsManager
                self.tunnelsListVC?.setTunnelsManager(tunnelsManager: tunnelsManager)

                tunnelsManager.activationDelegate = self

                self.onTunnelsManagerReady?(tunnelsManager)
                self.onTunnelsManagerReady = nil

                let userId = SharedStorage.shared.getCurrentUser()?.id
                if(userId == nil) {
                    wg_log(.info, message: "No UserId found, navigating to sign in")

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        let signInVC = SignInViewController()
                        let navController = UINavigationController(rootViewController: signInVC)
                        navController.modalPresentationStyle = .fullScreen
                        window.rootViewController = navController
                        window.makeKeyAndVisible()
                    }

                    return
                }

                let existingTunnels = SharedStorage.shared.getDaemonKeyPairByUserId(userId!)
                if(existingTunnels == nil) {
                    wg_log(.info, message: "UserId found, but no related tunnels, navigating to sign in")

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        let signInVC = SignInViewController()
                        let navController = UINavigationController(rootViewController: signInVC)
                        navController.modalPresentationStyle = .fullScreen
                        window.rootViewController = navController
                        window.makeKeyAndVisible()
                    }

                    return
                }
            }
        }
    }

    func allTunnelNames() -> [String]? {
        guard let tunnelsManager = self.tunnelsManager else { return nil }
        return tunnelsManager.mapTunnels { $0.name }
    }
}

extension MainViewController: TunnelsManagerActivationDelegate {
    func tunnelActivationAttemptFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationAttemptError) {
        ErrorPresenter.showErrorAlert(error: error, from: self)
    }

    func tunnelActivationAttemptSucceeded(tunnel: TunnelContainer) {
        // Nothing to do
    }

    func tunnelActivationFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationError) {
        ErrorPresenter.showErrorAlert(error: error, from: self)
    }

    func tunnelActivationSucceeded(tunnel: TunnelContainer) {
        // Nothing to do
    }
}

extension MainViewController {
    func refreshTunnelConnectionStatuses() {
        if let tunnelsManager = tunnelsManager {
            tunnelsManager.refreshStatuses()
        }
    }

    func showTunnelDetailForTunnel(named tunnelName: String, animated: Bool, shouldToggleStatus: Bool) {
        let showTunnelDetailBlock: (TunnelsManager) -> Void = { [weak self] tunnelsManager in
            guard let self = self else { return }
            guard let tunnelsListVC = self.tunnelsListVC else { return }
            if let tunnel = tunnelsManager.tunnel(named: tunnelName) {
                tunnelsListVC.showTunnelDetail(for: tunnel, animated: false)
                if shouldToggleStatus {
                    if tunnel.status == .inactive {
                        tunnelsManager.startActivation(of: tunnel)
                    } else if tunnel.status == .active {
                        tunnelsManager.startDeactivation(of: tunnel)
                    }
                }
            }
        }
        if let tunnelsManager = tunnelsManager {
            showTunnelDetailBlock(tunnelsManager)
        } else {
            onTunnelsManagerReady = showTunnelDetailBlock
        }
    }
}

extension MainViewController: UISplitViewControllerDelegate {
    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        // On iPhone, if the secondaryVC (detailVC) is just a UIViewController, it indicates that it's empty,
        // so just show the primaryVC (masterVC).
        let detailVC = (secondaryViewController as? UINavigationController)?.viewControllers.first
        let isDetailVCEmpty: Bool
        if let detailVC = detailVC {
            isDetailVCEmpty = (type(of: detailVC) == UIViewController.self)
        } else {
            isDetailVCEmpty = true
        }
        return isDetailVCEmpty
    }
}
