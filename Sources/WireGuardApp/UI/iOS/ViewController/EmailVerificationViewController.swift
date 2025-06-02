import UIKit

class EmailVerificationViewController: BaseViewController {

    private let stackView = UIStackView()
    private var codeFields: [CodeTextField] = []

    private let email: String

    init(email: String) {
        self.email = email
        super.init(nibName: nil, bundle: nil)
    }

    // Required because we have a custom init
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter the 6-digit code we sent to your email"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.numberOfLines = 0
        label.textColor = UIColor(hex: "#111279")
        label.textAlignment = .center
        return label
    }()

    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Confirm", for: .normal)
        button.backgroundColor = UIColor(hex: "#111279")
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()

    private let resendCodeButton: UIButton = {
        let button = UIButton(type: .system)
        let title = "Resend Code"
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(hex: "#111279"),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let attributedTitle = NSAttributedString(string: title, attributes: attributes)
        button.setAttributedTitle(attributedTitle, for: .normal)
        return button
    }()

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        let originalImage = UIImage(named: "jimber_logo_white")
        imageView.image = originalImage?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = UIColor(hex: "#111279")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()


    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        setupLogo()
        setupCodeFields()
        setupLayout()

        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        resendCodeButton.addTarget(self, action: #selector(resendTapped), for: .touchUpInside)

        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false  // So buttons and other UI elements still receive touches
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setupCodeFields() {
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for i in 0..<6 {
            let field = CodeTextField()
            field.tag = i
            field.borderStyle = .roundedRect
            field.textAlignment = .center
            field.font = .systemFont(ofSize: 20, weight: .medium)
            field.keyboardType = .numberPad
            field.delegate = self
            field.backspaceDelegate = self
            field.translatesAutoresizingMaskIntoConstraints = false
            field.heightAnchor.constraint(equalToConstant: 44).isActive = true

            field.textColor = UIColor(hex: "#111279")

            field.backgroundColor = .white
            field.layer.borderColor = UIColor(hex: "#111279").cgColor
            field.layer.borderWidth = 1
            field.layer.cornerRadius = 5
            field.clipsToBounds = true

            codeFields.append(field)
            stackView.addArrangedSubview(field)
        }
    }

    private func setupLogo() {
        view.addSubview(logoImageView)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 280),
            logoImageView.heightAnchor.constraint(equalToConstant: 111)
        ])
    }

    private func setupLayout() {
        [titleLabel, stackView, confirmButton, resendCodeButton].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 44),
            stackView.widthAnchor.constraint(equalToConstant: 6 * 40 + 5 * 12),

            confirmButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 32),
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            confirmButton.heightAnchor.constraint(equalToConstant: 50),

            resendCodeButton.topAnchor.constraint(equalTo: confirmButton.bottomAnchor, constant: 16),
            resendCodeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func confirmTapped() {
        let code = Int(codeFields.map { $0.text ?? "" }.joined())!

        Task {
            do {
                let userAuthentication = try await verifyEmailWithCode(email: self.email, token: code)
                let companyName = userAuthentication.companyName
                let userId = userAuthentication.userId

                if let _ = SharedStorage.shared.getDaemonKeyPairByUserId(userId) {
                    wg_log(.info, message: "Found daemons for user, loading...")
                    self.loadExistingDaemons()
                    return
                }

                guard let daemonName = await self.promptTunnelNameAsync() else {
                    self.showToast(message: "Tunnel creation cancelled")
                    return
                }

                wg_log(.info, message: "Registering new daemon")

                let result = try await register(userAuthentication: userAuthentication, daemonName: daemonName)

                wg_log(.info, message: "Registered new daemon \(result.daemonId)")

                await self.importAndNavigate(
                    configurationString: result.configurationString,
                    companyName: companyName,
                    daemonId: result.daemonId,
                    userId: userId
                )
            } catch {
                self.showToast(message: error.localizedDescription)
            }
        }
    }

    func loadExistingDaemons() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = MainViewController()
            window.makeKeyAndVisible()
        }
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

    func addTunnel(tunnelsManager: TunnelsManager, configuration: TunnelConfiguration) async throws -> TunnelContainer {
        return try await withCheckedThrowingContinuation { continuation in
            tunnelsManager.add(tunnelConfiguration: configuration) { result in
                switch result {
                case .success(let tunnelContainer):
                    continuation.resume(returning: tunnelContainer)
                case .failure(let error):
                    let daemonId = configuration.daemonId
                    let daemonKeyPair = SharedStorage.shared.getDaemonKeyPairByDaemonId(configuration.daemonId!)

                    Task {
                        _ =  await deleteDaemon(daemonId: daemonId!, company: daemonKeyPair!.companyName, sk: daemonKeyPair!.baseEncodedSkEd25519)

                        // Delete daemon in shared storage
                        SharedStorage.shared.clearDaemonKeys(daemonId: daemonId!)
                        SharedStorage.shared.clearUserLoginData()
                    }

                    self.showToast(message: "Cancellation in process")
                    continuation.resume(throwing: error)  // Throw the error if it fails
                }
            }
        }
    }

    func importAndNavigate(configurationString: String, companyName: String, daemonId: Int, userId: Int ) async {
        let tunnelName = companyName + "-" + String(daemonId)

        guard let scannedTunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: configurationString, called: tunnelName, userId: userId, daemonId: daemonId) else {
            wg_log(.error, message: "Invalid configuration \(configurationString)")
            return
        }

        do {
            let tunnelsManager = try await createTunnelsManager()
            _ = try await addTunnel(tunnelsManager: tunnelsManager, configuration: scannedTunnelConfiguration)

            DispatchQueue.main.async {
                let masterVC = TunnelsListTableViewController()
                masterVC.setTunnelsManager(tunnelsManager: tunnelsManager)

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = MainViewController()
                    window.makeKeyAndVisible()
                }
            }
        } catch {
            wg_log(.error, message: "Error occured in importAndNavigate \(error)")
        }
    }


    @objc private func resendTapped() {
        Task {
            await resendTappedAsync();
        }
    }

    @objc private func resendTappedAsync() async {
        do {
            _ = try await sendVerificationEmail(email: self.email)
            showToast(message: "Email succesfully sent")
        } catch {
            showToast(message: "Could not send verification email, please contact support")
            return
        }
    }
}

// MARK: - UITextFieldDelegate

extension EmailVerificationViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let codeField = textField as? CodeTextField else { return false }

        if string.isEmpty {
            return true // Let deleteBackward handle backspace
        }

        if string.count == 1 {
            codeField.text = string
            let nextTag = codeField.tag + 1
            if nextTag < codeFields.count {
                codeFields[nextTag].becomeFirstResponder()
            }
            return false
        }

        return false
    }
}

// MARK: - CodeTextFieldDelegate

extension EmailVerificationViewController: CodeTextFieldDelegate {
    func didPressBackspace(in textField: CodeTextField) {
        let prevTag = textField.tag - 1
        if prevTag >= 0 {
            codeFields[prevTag].text = ""
            codeFields[prevTag].becomeFirstResponder()
        } else {
            textField.text = ""
        }
    }
}

// MARK: - CodeTextField

protocol CodeTextFieldDelegate: AnyObject {
    func didPressBackspace(in textField: CodeTextField)
}

class CodeTextField: UITextField {
    weak var backspaceDelegate: CodeTextFieldDelegate?

    override func deleteBackward() {
        let wasEmpty = text?.isEmpty ?? true
        super.deleteBackward()
        backspaceDelegate?.didPressBackspace(in: self)

        // Optional: Clear if not empty
        if !wasEmpty {
            text = ""
        }
    }
}
