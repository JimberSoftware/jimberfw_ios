// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class SwitchCell: UITableViewCell {

    // MARK: - Public API

    var message: String {
        get { return textLabel?.text ?? "" }
        set { textLabel?.text = newValue }
    }

    var isOn: Bool {
        get { return switchView.isOn }
        set { switchView.isOn = newValue }
    }

    var isEnabled: Bool {
        get { return switchView.isEnabled }
        set {
            switchView.isEnabled = newValue
            textLabel?.textColor = newValue ? .label : .systemGray
        }
    }

    var messageTextColor: UIColor? {
        get { return textLabel?.textColor }
        set { textLabel?.textColor = newValue }
    }

    var onSwitchToggled: ((Bool) -> Void)?

    var statusObservationToken: AnyObject?
    var isOnDemandEnabledObservationToken: AnyObject?
    var hasOnDemandRulesObservationToken: AnyObject?

    // MARK: - Private/Internal

    /// Make `switchView` readable from outside but not replaceable
    private(set) var switchView = UISwitch()

    // MARK: - Initializers

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    // MARK: - Setup

    private func configure() {
        accessoryView = switchView

        // ON state color
        switchView.onTintColor = .systemBlue

        // Thumb color
        switchView.thumbTintColor = .white

        // OFF state appearance
        switchView.tintColor = .systemGray4
        switchView.backgroundColor = .systemGray4
        switchView.layer.cornerRadius = 16
        switchView.clipsToBounds = true

        switchView.addTarget(self,
                             action: #selector(switchToggled),
                             for: .valueChanged)

        textLabel?.numberOfLines = 1
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure correct corner radius after layout
        switchView.layer.cornerRadius = switchView.bounds.height / 2
    }

    // MARK: - Actions

    @objc private func switchToggled() {
        onSwitchToggled?(switchView.isOn)
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()

        onSwitchToggled = nil
        isEnabled = true
        message = ""
        isOn = false

        statusObservationToken = nil
        isOnDemandEnabledObservationToken = nil
        hasOnDemandRulesObservationToken = nil
    }
}