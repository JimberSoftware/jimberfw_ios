import UIKit
import GoogleSignIn
import MSAL

class SignInViewController: BaseViewController {

    // Update the below to your client ID. The below is for running the demo only
    let kClientID = "f1373772-6623-4090-9204-3cb04b9d46c9"
    let kAuthority = "https://login.microsoftonline.com/common"

    let kScopes: [String] = ["user.read"] // request permission to read the profile of the signed-in user

    var accessToken = String()
    var applicationContext : MSALPublicClientApplication?
    var webViewParameters : MSALWebviewParameters?
    var currentAccount: MSALAccount?

    override func viewDidLoad() {
        print("Loaded")
        super.viewDidLoad()

        GIDSignIn.sharedInstance.signOut()
        GIDSignIn.sharedInstance.disconnect()

        self.navigationItem.hidesBackButton = true

        // Set the background color of the view (optional, in case the image is not fully loaded)
        view.backgroundColor = .white

        // Create a container for vertical stacking (like LinearLayout)
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        // Set up constraints for the stack view
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 280)
        ])

        // Add the logo image (like AppCompatImageView)
        let logoImageView = UIImageView(image: UIImage(named: "jimber_logo_full"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(logoImageView)
        logoImageView.heightAnchor.constraint(equalToConstant: 100).isActive = true

        // Add sign-in title (like TextView)
        let titleLabel = UILabel()
        titleLabel.text = "Sign in to your account"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(hex: "#111279")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(titleLabel)
        titleLabel.heightAnchor.constraint(equalToConstant: 40).isActive = true

        // Add Google sign-in button
        let googleSignInButton = createSignInButton(title: "Sign in with Google", imageName: "google_icon", action: #selector(googleSignInTapped))
        stackView.addArrangedSubview(googleSignInButton)

        // Add Microsoft sign-in button
        let microsoftSignInButton = createSignInButton(title: "Sign in with Microsoft", imageName: "microsoft_icon", action: #selector(microsoftSignInTapped))
        stackView.addArrangedSubview(microsoftSignInButton)

        // Add Email sign-in button
        let emailSignInButton = createSignInButton(title: "Sign in with Email", imageName: "email_icon", action: #selector(emailSignInTapped))
        stackView.addArrangedSubview(emailSignInButton)

        do {
                  try self.initMSAL()
              } catch let error {
                  print(error)
              }
    }

    func initMSAL() throws {

           guard let authorityURL = URL(string: kAuthority) else {
               print("erreur")
               return
           }

           let authority = try MSALAADAuthority(url: authorityURL)

           let msalConfiguration = MSALPublicClientApplicationConfig(clientId: kClientID, redirectUri: nil, authority: authority)
            MSALGlobalConfig.brokerAvailability = .none;
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
       button.setTitleColor(.white, for: .normal)
       button.backgroundColor = UIColor(hex: "#111279") // Customize the background color
       button.layer.cornerRadius = 4
       button.tintColor = .white
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
       titleLabel.font = UIFont.boldSystemFont(ofSize: 14)
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

    // Action methods for button taps
    @objc func googleSignInTapped() {
        GIDSignIn.sharedInstance.disconnect()
        GIDSignIn.sharedInstance.signOut()

        GIDSignIn.sharedInstance.signIn(
               withPresenting: self,
               hint: nil,
               additionalScopes: nil
        ) { signInResult, error in
            if let error = error {
                return
            }

            Task {
                do {
                    let idToken = signInResult?.user.idToken?.tokenString

                    let userAuthentication = try await getUserAuthentication(idToken: idToken!, authenticationType: .google)

                    let companyName = userAuthentication.companyName
                    let userId = userAuthentication.userId

                    let alreadyInStorage = SharedStorage.shared.getDaemonKeyPairByUserId(userId)
                    print(alreadyInStorage)
                    if(alreadyInStorage != nil) {
                        self.loadExistingDaemons()
                        return;
                    }


                    let result = try await register(userAuthentication: userAuthentication, daemonName: "lennygdaemon")

                    await self.importAndNavigate(configurationString: result.configurationString, companyName: companyName, daemonId: result.daemonId, userId: userId)

                }
                catch(let error){
                        DispatchQueue.main.async {
                               let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                               alert.addAction(UIAlertAction(title: "OK", style: .default))
                               UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
                           }
                    }
            }
        }
    }

    func loadExistingDaemons() {
        print("GOING TO MAIN VIEW CONTROLLER")
        
        let mainViewController = MainViewController()
        mainViewController.modalPresentationStyle = .fullScreen // Ensures the view controller covers the entire screen
        self.present(mainViewController, animated: true, completion: nil)
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
                    continuation.resume(throwing: error)  // Throw the error if it fails
                }
            }
        }
    }

    func importAndNavigate(configurationString: String, companyName: String, daemonId: Int, userId: Int ) async {
        guard let scannedTunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: configurationString, called: "Registered", userId: userId, daemonId: daemonId) else {
            print("Invalid configuration")
            return
        }
        scannedTunnelConfiguration.name = companyName

        do {
            let tunnelsManager = try await createTunnelsManager()
            let tunnel = try await addTunnel(tunnelsManager: tunnelsManager, configuration: scannedTunnelConfiguration)

            DispatchQueue.main.async {
                let masterVC = TunnelsListTableViewController()
                masterVC.setTunnelsManager(tunnelsManager: tunnelsManager)

                if let navigationController = self.navigationController {
                    navigationController.setViewControllers([masterVC], animated: true)
                } else {
                    self.present(masterVC, animated: true, completion: nil)
                }
            }
        } catch {
            print("Error: \(error)")
        }
    }
    func acquireTokenInteractively() {

        guard let applicationContext = self.applicationContext else { return }
        guard let webViewParameters = self.webViewParameters else { return }

        // #1
        let parameters = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webViewParameters)
        parameters.promptType = .selectAccount

        // #2
        applicationContext.acquireToken(with: parameters) { (result, error) in

            // #3
            if let error = error {

                print("error 1 " + error.localizedDescription)
                return
            }

            guard let result = result else {

                print("error" + error!.localizedDescription)
                return
            }

            // #4
            self.accessToken = result.accessToken
            self.updateCurrentAccount(account: result.account)

            print(self.accessToken)
        }
    }

    @objc func microsoftSignInTapped() {
        acquireTokenInteractively()
        print("Microsoft Sign-In Tapped")
    }


    @objc func emailSignInTapped() {
        print("Email Sign-In Tapped")
    }

    func updateCurrentAccount(account: MSALAccount?) {
        self.currentAccount = account
    }
}
