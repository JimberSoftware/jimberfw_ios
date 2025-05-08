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

        sections.append([.getStorage, .deleteStorage]) // Always include development options

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
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))

        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false

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
        let allData = SharedStorage.shared.getAll()


        let pk = "2JRCMmXUwKCalXG8OzoCp7mbwyk/kqSTCmkbHP6c9Og="
        let sk = "3HliYd7haohMc0a8IQTUYXFkMkmBkrO1yWQrJGOjKcY="


        let kp = generateWireguardConfigurationKeys(pk: pk, sk: sk)

        print(kp?.base64EncodedPkCurveX25519)
        print(kp?.base64EncodedSkCurveX25519)

        wg_log(.info, message: "Getting storage")
        wg_log(.info, message: String(describing: allData))

        UIPasteboard.general.string = String(describing: allData)
        showToast(message: "Storage info copied to clipboard")
    }

    func deleteStorageAction() async {
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

            wg_log(.info, message: "Removing all storage")
            SharedStorage.shared.clearAll()

            navigateToSignIn(message: "Succesfully deleted storage")

        } catch {
            wg_log(.error, message: "Could not clear storage: \(error)")
        }
    }

    func signOutAction() async {
        do {
            let userId = SharedStorage.shared.getCurrentUser()?.id;

            let tunnelsManager = try await createTunnelsManager()
            let tunnels = tunnelsManager.allTunnelsOfUserId(userId: userId!)

            wg_log(.info, message: "Deactivating tunnels")
            for tunnel in tunnels {
                wg_log(.info, message: "Deactivating tunnel \(tunnel.name)")
                tunnelsManager.startDeactivation(of: tunnel)
            }

            wg_log(.info, message: "Clearing user login data")
            SharedStorage.shared.clearUserLoginData()

            navigateToSignIn(message: "Succesfully signed out")
        }

        catch {
            wg_log(.error, message: "Error in sign out action: \(error)")
        }
    }

    func navigateToSignIn(message: String) {
        let signInVC = SignInViewController()
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = signInVC
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
        switch section {
        case 0:
            return tr("settingsSectionTitleAbout")
        case 1:
            return tr("settingsSectionTitleTunnelLog")
        case 2:
            return tr("settingsSectionTitleManagement")
        case 3:
            return "Development Options"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let field = settingsFieldsBySection[indexPath.section][indexPath.row]
        if field == .iosAppVersion || field == .goBackendVersion {
            let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
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
            cell.buttonText = field.localizedUIString
            cell.onTapped = { [weak self] in
                self?.presentLogView()
            }
            return cell
        } else if field == .loggedInUser {
            let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
            cell.copyableGesture = false
            cell.key = field.localizedUIString

            let email = SharedStorage.shared.getCurrentUser()?.email
            cell.value = email!

            return cell

        } else if field == .signOut {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
            cell.buttonText = field.localizedUIString
            cell.onTapped = { [weak self] in
                Task {
                    await self?.signOutAction()
                }
            }
            return cell
        } else if field == .getStorage {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
            cell.buttonText = field.localizedUIString
            cell.onTapped = { [weak self] in
                Task {
                    await self?.getStorageAction()
                }
            }
            return cell
        } else if field == .deleteStorage {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
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
