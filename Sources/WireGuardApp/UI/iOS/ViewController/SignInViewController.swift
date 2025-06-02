import UIKit
import GoogleSignIn
import MSAL

class SignInViewController: BaseViewController {

    // Update the below to your client ID. The below is for running the demo only
    let kClientID = "f1373772-6623-4090-9204-3cb04b9d46c9"
    let kAuthority = "https://login.microsoftonline.com/common"

    let kScopes: [String] = ["f1373772-6623-4090-9204-3cb04b9d46c9/.default"] // request permission to read the profile of the signed-in user

    var applicationContext : MSALPublicClientApplication?
    var webViewParameters : MSALWebviewParameters?
    var currentAccount: MSALAccount?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        GIDSignIn.sharedInstance.signOut()
        GIDSignIn.sharedInstance.disconnect()

        // Background color
        view.backgroundColor = .white

        // Create custom "three dots" settings button
        let settingsButton = UIButton(type: .system)
        settingsButton.setTitle("⋯", for: .normal) // Unicode ellipsis
        settingsButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 28)
        settingsButton.tintColor =  UIColor(hex: "#111279")
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)

        // Pin the button to top-right corner
        NSLayoutConstraint.activate([
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            settingsButton.widthAnchor.constraint(equalToConstant: 30),
            settingsButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Create the main stack view
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 280)
        ])

        let logoImageView = UIImageView(image: UIImage(named: "jimber_logo_white")?.withRenderingMode(.alwaysTemplate))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.tintColor = UIColor(hex: "#111279")
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(logoImageView)
        logoImageView.heightAnchor.constraint(equalToConstant: 275).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Sign in to your account"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(titleLabel)
        titleLabel.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let googleSignInButton = createSignInButton(title: "Sign in with Google", imageName: "google_icon", action: #selector(googleSignInTapped))
        stackView.addArrangedSubview(googleSignInButton)

        let microsoftSignInButton = createSignInButton(title: "Sign in with Microsoft", imageName: "microsoft_icon", action: #selector(microsoftSignInTapped))
        stackView.addArrangedSubview(microsoftSignInButton)

        let emailSignInButton = createSignInButton(title: "Sign in with Email", imageName: "email_icon", action: #selector(emailSignInTapped))
        stackView.addArrangedSubview(emailSignInButton)

        do {
            try self.initMSAL()
        } catch let error {
            wg_log(.error, message: "Could not init MSAL: \(error)")
        }
    }

    @objc func openSettings() {
        let settingsVC = SettingsTableViewController(tunnelsManager: nil)
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    func initMSAL() throws {
           guard let authorityURL = URL(string: kAuthority) else {
               wg_log(.error, message: "Could not create authority URL")
               return
           }

           let authority = try MSALAADAuthority(url: authorityURL)

           let msalConfiguration = MSALPublicClientApplicationConfig(clientId: kClientID, redirectUri: nil, authority: authority)
           MSALGlobalConfig.brokerAvailability = .none
           self.applicationContext = try MSALPublicClientApplication(configuration: msalConfiguration)
           self.initWebViewParams()
       }

    func initWebViewParams() {
        self.webViewParameters = MSALWebviewParameters(authPresentationViewController: self)
    }


    // Helper function to create sign-in buttons
    func createSignInButton(title: String, imageName: String, action: Selector) -> UIButton {
       // Create the button
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(hex: "#111279")
        button.layer.cornerRadius = 4
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.translatesAutoresizingMaskIntoConstraints = false

       // Create a horizontal stack view for the title and icon
       let stackView = UIStackView()
       stackView.axis = .horizontal
       stackView.spacing = 8
       stackView.alignment = .center
       stackView.distribution = .fill
       stackView.translatesAutoresizingMaskIntoConstraints = false

       // Create and add the icon image view to the stack
       let iconImageView = UIImageView(image: UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate))
        iconImageView.tintColor = .white
       iconImageView.contentMode = .scaleAspectFit
       iconImageView.translatesAutoresizingMaskIntoConstraints = false
       iconImageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
       iconImageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
       stackView.addArrangedSubview(iconImageView)

       // Create and add the title label to the stack
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .heavy) // Bigger and bolder
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)


       // Add the stack view to the button
       button.addSubview(stackView)

       // Set the fixed width for the button
       button.widthAnchor.constraint(equalToConstant: 280).isActive = true
       button.heightAnchor.constraint(equalToConstant: 50).isActive = true

       // Set constraints for the stack view within the button
       NSLayoutConstraint.activate([
           stackView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
           stackView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
           stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
       ])

        // Add a gesture recognizer to the stack view (to listen for taps)
        let tapGesture = UITapGestureRecognizer(target: self, action: action)
        stackView.addGestureRecognizer(tapGesture)

       return button
    }

    @objc func googleSignInTapped() {
        wg_log(.info, message: "Google Sign In tapped")

        GIDSignIn.sharedInstance.disconnect()
        GIDSignIn.sharedInstance.signOut()

        GIDSignIn.sharedInstance.signIn(
            withPresenting: self,
            hint: nil,
            additionalScopes: nil
        ) { signInResult, error in
            if let error = error {
                wg_log(.error, message: "Google SignIn error: \(error)")
                self.showToast(message: "Sign-In failed: \(error.localizedDescription)")
                return
            }

            guard let idToken = signInResult?.user.idToken?.tokenString else {
                self.showToast(message: "No ID token received")
                return
            }

            Task {
                do {
                    let userAuthentication = try await getUserAuthentication(idToken: idToken, authenticationType: .google)
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
    }

    @objc func microsoftSignInTapped() {
        wg_log(.info, message: "Microsoft Sign In tapped")

        guard let applicationContext = self.applicationContext else { return }
        guard let webViewParameters = self.webViewParameters else { return }

        let parameters = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webViewParameters)
        parameters.promptType = .selectAccount

        applicationContext.acquireToken(with: parameters) { (result, error) in
            if let error = error {
                wg_log(.error, message: "Error in acquire token 1: \(error.localizedDescription)")
                return
            }

            let accessToken = result!.accessToken
            self.updateCurrentAccount(account: result!.account)

            Task {
                do {
                    let userAuthentication = try await getUserAuthentication(idToken: accessToken, authenticationType: .microsoft)
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

    @objc func emailSignInTapped() {
        wg_log(.info, message: "Email Sign In tapped")

        let emailVC = EmailRegistrationViewController()
        navigationController?.pushViewController(emailVC, animated: true)
    }

    func updateCurrentAccount(account: MSALAccount?) {
        self.currentAccount = account
    }
}
