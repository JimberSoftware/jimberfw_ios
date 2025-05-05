import UIKit

class LoadingViewController: BaseViewController {

    // Create the loading spinner
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view background color
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)

        // Set up the spinner
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        // Center the spinner in the view
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Start the spinner
        activityIndicator.startAnimating()
    }

    // Function to stop the loading spinner and dismiss the controller
    func stopLoading() {
        activityIndicator.stopAnimating()
        dismiss(animated: true, completion: nil)
    }
}
