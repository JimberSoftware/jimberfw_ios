import UIKit

class EmailRegistrationViewController: BaseViewController {

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "jimber_logo_white")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Sign in to your account"
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let emailLabel: UILabel = {
        let label = UILabel()
        label.text = "Email"
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = .white
        return label
    }()

    private let emailTextField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .emailAddress
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.layer.cornerRadius = 4
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.white.cgColor
        tf.setLeftPaddingPoints(12)
        tf.setRightPaddingPoints(12)
        tf.textColor = .white
        return tf
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = .systemRed
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let proceedButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Continue", for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        btn.backgroundColor = .white
        btn.setTitleColor(UIColor(hex: "#1c1b20"), for: .normal)
        btn.layer.cornerRadius = 4
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        btn.isEnabled = false
        btn.alpha = 0.5 // Show as disabled
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#1c1b20")

        setupNavigationBar()
        setupViews()
        setupConstraints()
        setupActions()
    }

    private func setupNavigationBar() {
        // Remove custom left button — use default back button
        navigationItem.leftBarButtonItem = nil

        // Enable default back button appearance and tint color
        navigationController?.navigationBar.tintColor = .white

        // Remove right bar button item (the 3 dots)
        navigationItem.rightBarButtonItem = nil
    }

    private func setupViews() {
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(emailLabel)
        view.addSubview(emailTextField)
        view.addSubview(errorLabel)
        view.addSubview(proceedButton)

        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        emailTextField.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        proceedButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 280),
            logoImageView.heightAnchor.constraint(equalToConstant: 111),

            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 230),
            titleLabel.heightAnchor.constraint(equalToConstant: 40),

            emailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            emailLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emailLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            emailTextField.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 4),
            emailTextField.leadingAnchor.constraint(equalTo: emailLabel.leadingAnchor),
            emailTextField.trailingAnchor.constraint(equalTo: emailLabel.trailingAnchor),
            emailTextField.heightAnchor.constraint(equalToConstant: 40),

            errorLabel.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 6),
            errorLabel.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),

            proceedButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
            proceedButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            proceedButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func setupActions() {
        proceedButton.addTarget(self, action: #selector(proceedButtonTapped), for: .touchUpInside)
        emailTextField.addTarget(self, action: #selector(emailTextChanged), for: .editingChanged)
    }

    @objc private func proceedButtonTapped() {
        Task {
            await proceedButtonTappedAsync()
        }
    }

    @objc private func proceedButtonTappedAsync() async {
        guard let email = emailTextField.text, isValidEmail(email) else {
            errorLabel.text = "Please enter a valid email address."
            errorLabel.isHidden = false
            return
        }

        do {
            _ = try await sendVerificationEmail(email: email)
            errorLabel.isHidden = true // Clear any prior error

            let emailVC = EmailVerificationViewController(email: email)
            navigationController?.pushViewController(emailVC, animated: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                emailVC.showToast(message: "Email succesfully sent")
            }
        } catch {
            showToast(message: "Could not send verification email, please contact support")
            return
        }
    }

    @objc private func emailTextChanged() {
        let text = emailTextField.text ?? ""

        if isValidEmail(text) {
            proceedButton.isEnabled = true
            proceedButton.alpha = 1
        } else {
            proceedButton.isEnabled = false
            proceedButton.alpha = 0.5
        }

        // Do not show or hide error label here
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegEx)
        return predicate.evaluate(with: email)
    }
}

// MARK: - UITextField Padding extension
extension UITextField {
    func setLeftPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }

    func setRightPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.rightView = paddingView
        self.rightViewMode = .always
    }
}
