// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class TunnelListCell: UITableViewCell {

    // MARK: - Public API

    var tunnel: TunnelContainer? {
        didSet {
            nameLabel.text = tunnel?.name ?? ""
            nameObservationToken = tunnel?.observe(\.name) { [weak self] tunnel, _ in
                self?.nameLabel.text = tunnel.name
            }
            update(from: tunnel, animated: false)
            statusObservationToken = tunnel?.observe(\.status) { [weak self] tunnel, _ in
                self?.update(from: tunnel, animated: true)
            }
            isOnDemandEnabledObservationToken = tunnel?.observe(\.isActivateOnDemandEnabled) { [weak self] tunnel, _ in
                self?.update(from: tunnel, animated: true)
            }
            hasOnDemandRulesObservationToken = tunnel?.observe(\.hasOnDemandRules) { [weak self] tunnel, _ in
                self?.update(from: tunnel, animated: true)
            }
        }
    }

    var onSwitchToggled: ((Bool) -> Void)?

    // MARK: - Views

    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = UIColor(hex: "#111279")
        return label
    }()

    let onDemandLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.textColor = .secondaryLabel
        return label
    }()

    let busyIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    /// Make the switch readable externally
    private(set) var statusSwitch = UISwitch()

    // MARK: - Observation tokens

    private var nameObservationToken: NSKeyValueObservation?
    private var statusObservationToken: NSKeyValueObservation?
    private var isOnDemandEnabledObservationToken: NSKeyValueObservation?
    private var hasOnDemandRulesObservationToken: NSKeyValueObservation?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .white
        contentView.backgroundColor = .white

        accessoryType = .none
        configureChevron()
        configureSubviews()
        configureSwitch()
        setupConstraints()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        selectionStyle = .none
        backgroundColor = .white
        contentView.backgroundColor = .white

        accessoryType = .none
        configureChevron()
        configureSubviews()
        configureSwitch()
        setupConstraints()
    }

    // MARK: - Configuration

    private func configureChevron() {
        let chevronImage = UIImage(systemName: "chevron.right")?.withRenderingMode(.alwaysTemplate)
        let chevronImageView = UIImageView(image: chevronImage)
        chevronImageView.tintColor = UIColor(hex: "#111279")

        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 24))
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(chevronImageView)
        NSLayoutConstraint.activate([
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 8),
            chevronImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
        accessoryView = containerView
    }

    private func configureSubviews() {
        for subview in [statusSwitch, busyIndicator, onDemandLabel, nameLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subview)
        }
    }

    private func configureSwitch() {
        // Customize the UISwitch only
        statusSwitch.onTintColor = UIColor.systemGreen  // ON color
        statusSwitch.thumbTintColor = .white          // Knob color

        // OFF state appearance
        statusSwitch.tintColor = UIColor.systemGray4
        statusSwitch.backgroundColor = UIColor.systemGray4
        statusSwitch.layer.cornerRadius = 16
        statusSwitch.clipsToBounds = true

        // Add action
        statusSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }

    private func setupConstraints() {
        let nameLabelBottomConstraint =
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: nameLabel.bottomAnchor, multiplier: 1)
        nameLabelBottomConstraint.priority = .defaultLow

        NSLayoutConstraint.activate([
            statusSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusSwitch.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

            nameLabel.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 1),
            nameLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: contentView.layoutMarginsGuide.leadingAnchor, multiplier: 1),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusSwitch.leadingAnchor),
            nameLabelBottomConstraint,

            onDemandLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            onDemandLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: nameLabel.trailingAnchor, multiplier: 1),

            busyIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            busyIndicator.leadingAnchor.constraint(greaterThanOrEqualToSystemSpacingAfter: nameLabel.trailingAnchor, multiplier: 1)
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        statusSwitch.layer.cornerRadius = statusSwitch.bounds.height / 2
    }

    // MARK: - Actions

    @objc private func switchToggled() {
        onSwitchToggled?(statusSwitch.isOn)
    }

    // MARK: - Tunnel Updates

    private func update(from tunnel: TunnelContainer?, animated: Bool) {
        guard let tunnel = tunnel else {
            reset(animated: animated)
            return
        }

        let status = tunnel.status
        let isOnDemandEngaged = tunnel.isActivateOnDemandEnabled
        let shouldSwitchBeOn = ((status != .deactivating && status != .inactive) || isOnDemandEngaged)

        statusSwitch.setOn(shouldSwitchBeOn, animated: true)

        // Adaptive color for on-demand
        if isOnDemandEngaged && !(status == .activating || status == .active) {
            statusSwitch.onTintColor = .systemYellow
        } else {
            statusSwitch.onTintColor = .systemGreen
        }

        statusSwitch.isUserInteractionEnabled = (status == .inactive || status == .active)

        if tunnel.hasOnDemandRules {
            onDemandLabel.text = isOnDemandEngaged ? tr("tunnelListCaptionOnDemand") : ""
            busyIndicator.stopAnimating()
            statusSwitch.isUserInteractionEnabled = true
        } else {
            onDemandLabel.text = ""
            if status == .inactive || status == .active {
                busyIndicator.stopAnimating()
            } else {
                busyIndicator.startAnimating()
            }
            statusSwitch.isUserInteractionEnabled = (status == .inactive || status == .active)
        }
    }

    private func reset(animated: Bool) {
        statusSwitch.thumbTintColor = nil
        statusSwitch.setOn(false, animated: animated)
        statusSwitch.isUserInteractionEnabled = false
        busyIndicator.stopAnimating()
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        reset(animated: false)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        statusSwitch.isEnabled = !editing
    }
}