import UIKit
import GoogleSignIn

class SignInViewController: BaseViewController {

    override func viewDidLoad() {
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

               print(signInResult?.user.idToken?.tokenString);

           }
    }

    @objc func microsoftSignInTapped() {
        // Microsoft sign-in logic
        print("Microsoft Sign-In Tapped")
        GIDSignIn.sharedInstance.signOut()
        GIDSignIn.sharedInstance.disconnect()
        print("done")
    }

    @objc func emailSignInTapped() {
        // Email sign-in logic
        print("Email Sign-In Tapped")
    }
}
