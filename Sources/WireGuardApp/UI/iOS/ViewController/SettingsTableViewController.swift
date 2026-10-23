// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log

class SettingsTableViewController: UITableViewController {

    enum SettingsFields {
        case iosAppVersion
        case goBackendVersion
        case viewLog
        case loggedInUser
        case signOut
        case getStorage
        case deleteStorage

        var localizedUIString: String {
            switch self {
            case .iosAppVersion: return tr("settingsVersionKeyWireGuardForIOS")
            case .goBackendVersion: return tr("settingsVersionKeyWireGuardGoBackend")
            case .viewLog: return tr("settingsViewLogButtonTitle")
            case .loggedInUser: return tr("settingsViewLoggedInUser")
            case .signOut: return tr("settingsViewLogButtonSignOut")
            case .getStorage: return tr("settingsViewLogButtonGetStorage")
            case .deleteStorage: return tr("settingsViewLogButtonClearStorage")
            }
        }
    }

    lazy var settingsFieldsBySection: [[SettingsFields]] = {
        var sections: [[SettingsFields]] = [
            [.iosAppVersion, .goBackendVersion],
            [.viewLog]
        ]

        if SharedStorage.shared.getCurrentUser() != nil {
            sections.append([.loggedInUser, .signOut])
        }

        sections.append([.deleteStorage]) // Always include development options

#if DEBUG
        // Copying diagnostics to the pasteboard is a debug aid only. It used to be
        // available in App Store builds and copied tokens and private keys.
        sections[sections.count - 1].insert(.getStorage, at: 0)
#endif

        return sections
    }()

    let tunnelsManager: TunnelsManager?
    var wireguardCaptionedImage: (view: UIView, size: CGSize)?

    init(tunnelsManager: TunnelsManager?) {
        self.tunnelsManager = tunnelsManager
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = tr("settingsViewTitle")

        let customColor = UIColor(hex: "#111279")
         navigationController?.navigationBar.titleTextAttributes = [
             .foregroundColor: customColor
         ]

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))

        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false

        tableView.backgroundColor = .white

        tableView.register(KeyValueCell.self)
        tableView.register(ButtonCell.self)

        tableView.tableFooterView = UIImageView(image: UIImage(named: "wireguard.pdf"))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let logo = tableView.tableFooterView else { return }

        let bottomPadding = max(tableView.layoutMargins.bottom, 10)
        let fullHeight = max(tableView.contentSize.height, tableView.bounds.size.height - tableView.layoutMargins.top - bottomPadding)

        let imageAspectRatio = logo.intrinsicContentSize.width / logo.intrinsicContentSize.height

        var height = tableView.estimatedRowHeight * 1.5
        var width = height * imageAspectRatio
        let maxWidth = view.bounds.size.width - max(tableView.layoutMargins.left + tableView.layoutMargins.right, 20)
        if width > maxWidth {
            width = maxWidth
            height = width / imageAspectRatio
        }

        let needsReload = height != logo.frame.height

        logo.frame = CGRect(x: (view.bounds.size.width - width) / 2, y: fullHeight - height, width: width, height: height)

        if needsReload {
            tableView.tableFooterView = logo
        }
    }

    @objc func doneTapped() {
        dismiss(animated: true, completion: nil)
    }

    func presentLogView() {
        let logVC = LogViewController()
        navigationController?.pushViewController(logVC, animated: true)
    }

    func createTunnelsManager() async throws -> TunnelsManager {
        return try await withCheckedThrowingContinuation { continuation in
            TunnelsManager.create { result in
                switch result {
                case .success(let tunnelsManager):
                    continuation.resume(returning: tunnelsManager)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getStorageAction() async {
        // Redacted on purpose: this string ends up on the system pasteboard.
        let diagnostics = SharedStorage.shared.getDiagnosticsSummary()

        wg_log(.info, message: "Diagnostics summary requested")
        UIPasteboard.general.string = String(describing: diagnostics)
        showToast(message: "Diagnostics copied to clipboard")
    }

    func deleteStorageAction() async {
        let spinner = showLoadingSpinner()
        defer { hideLoadingSpinner(spinner) }

        // Removing tunnels can fail; the wipe below must still happen.
        do {
            let tunnelsManager = try await createTunnelsManager()
            let tunnels = tunnelsManager.getAllTunnels()

            wg_log(.info, message: "All tunnels that will be removed")
            wg_log(.info, message: tunnels.map { $0.name}.joined(separator: ", "))

            for tunnel in tunnels {
                tunnelsManager.remove(tunnel: tunnel) { error in
                    if error != nil {
                        ErrorPresenter.showErrorAlert(error: error!, from: self)
                    } else {
                    }
                }
                wg_log(.info, message: "Removed \(tunnel.name)")
            }
        } catch {
            wg_log(.error, message: "Could not remove tunnels before deleting storage: \(error.safeLogDescription)")
        }

        // Revoke this device's refresh token before wiping the local state.
        wg_log(.info, message: "Logging out")
        await logoutSession()

        wg_log(.info, message: "Removing all storage")
        SharedStorage.shared.clearAll()
        ApiClient.apiService.clearSessionCookies()

        navigateToSignIn(message: "Succesfully deleted storage")
    }

    func signOutAction() async {
        let spinner = showLoadingSpinner()
        defer { hideLoadingSpinner(spinner) }

        // Tunnels first, but a failure here must not block signing out.
        if let userId = SharedStorage.shared.getCurrentUser()?.id {
            do {
                let tunnelsManager = try await createTunnelsManager()
                for tunnel in tunnelsManager.allTunnelsOfUserId(userId: userId) {
                    wg_log(.info, message: "Deactivating tunnel \(tunnel.name)")
                    tunnelsManager.startDeactivation(of: tunnel)
                }
            } catch {
                wg_log(.error, message: "Error deactivating tunnels during sign out: \(error.safeLogDescription)")
            }
        }

        // Revoke the refresh token server-side, then clear local session data.
        wg_log(.info, message: "Logging out")
        await logoutSession()

        wg_log(.info, message: "Clearing user login data")
        SharedStorage.shared.clearUserLoginData()
        ApiClient.apiService.clearSessionCookies()

        // Daemon key pairs are kept on purpose: signing in again reuses the
        // existing device instead of registering a new one.

        navigateToSignIn(message: "Succesfully signed out")
    }

    func navigateToSignIn(message: String) {
        let signInVC = SignInViewController()
        let navController = UINavigationController(rootViewController: signInVC)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            window.rootViewController = navController
            window.makeKeyAndVisible()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                signInVC.showToast(message: message)
            }
        }
    }
}

extension SettingsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return settingsFieldsBySection.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsFieldsBySection[section].count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < settingsFieldsBySection.count else { return nil }

        // Derive the header from the contents instead of the section index: the
        // logged-in and development sections are not always present.
        switch settingsFieldsBySection[section].first {
        case .iosAppVersion:
            return tr("settingsSectionTitleAbout")
        case .viewLog:
            return tr("settingsSectionTitleTunnelLog")
        case .loggedInUser:
            return tr("settingsSectionTitleManagement")
        case .getStorage, .deleteStorage:
            return "Development Options"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.textColor = UIColor(hex: "#111279")
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.text = self.tableView(tableView, titleForHeaderInSection: section)

        let containerView = UIView()
        containerView.addSubview(label)

        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4)
        ])

        return containerView
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let field = settingsFieldsBySection[indexPath.section][indexPath.row]
        if field == .iosAppVersion || field == .goBackendVersion {
            let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)

            cell.backgroundColor = .white
            cell.contentView.backgroundColor = .white

            cell.copyableGesture = false
            cell.key = field.localizedUIString
            if field == .iosAppVersion {
                var appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown version"
                if let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                    appVersion += " (\(appBuild))"
                }
                cell.value = appVersion
            } else if field == .goBackendVersion {
                cell.value = WIREGUARD_GO_VERSION
            }
            return cell
        } else if field == .viewLog {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)

            cell.backgroundColor = .white
            cell.contentView.backgroundColor = .white

            cell.buttonText = field.localizedUIString
            cell.onTapped = { [weak self] in
                self?.presentLogView()
            }
            return cell
        } else if field == .loggedInUser {
            let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)

            cell.backgroundColor = .white
            cell.contentView.backgroundColor = .white

            cell.copyableGesture = false
            cell.key = field.localizedUIString

            let email = SharedStorage.shared.getCurrentUser()?.email
            cell.value = email!

            return cell

        } else if field == .signOut {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)

            cell.backgroundColor = .white
            cell.contentView.backgroundColor = .white

            cell.buttonText = field.localizedUIString
            cell.onTapped = { [weak self] in
                Task {
                    await self?.signOutAction()
                }
            }
            return cell
        } else if field == .getStorage {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)

            cell.backgroundColor = .white
            cell.contentView.backgroundColor = .white

            cell.buttonText = field.localizedUIString
            cell.onTapped = { [weak self] in
                Task {
                    await self?.getStorageAction()
                }
            }
            return cell
        } else if field == .deleteStorage {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)

            cell.backgroundColor = .white
            cell.contentView.backgroundColor = .white

            cell.buttonText = field.localizedUIString
            cell.onTapped = { [weak self] in
                Task {
                    await self?.deleteStorageAction()
                }
            }
            return cell
        }
        fatalError()
    }
}
