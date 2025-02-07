import UIKit

class BaseViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        // Set the background image
        let backgroundImageView = UIImageView(image: UIImage(named: "jimber_bg"))
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)

        // Get the screen's width and height
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        // Set the width and height of the background image as a percentage of the screen's width and height
        let imageWidth: CGFloat = screenWidth * 0.7  // 50% of screen width
        let imageHeight: CGFloat = screenHeight * 0.7 // 30% of screen height

        // Ensure the image is positioned at the bottom-right corner
        NSLayoutConstraint.activate([
            backgroundImageView.widthAnchor.constraint(equalToConstant: imageWidth),
            backgroundImageView.heightAnchor.constraint(equalToConstant: imageHeight),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0), // Right margin
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0) // Bottom margin
        ])
    }
}
