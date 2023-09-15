//
//  WriteFloatingButtonView.swift
//  Scoop
//
//  Created by Jae hyuk Yim on 2023/09/01.
//

import UIKit
import Combine

protocol ReviewFloatingViewDelegate: AnyObject {
    func activateDimView(_ activate: Bool)
}

class ReviewFloatingView: UIView {

    weak var delegate: ReviewFloatingViewDelegate?
    var floatingButtonFlag: Bool = false
    var textLabelTappedSubject = PassthroughSubject<String, Never>()

    let categoryButtonImages: [PostCategory: UIImage] = [
        .restaurant: UIImage(named: "salad") ?? UIImage(),
        .cafe: UIImage(named: "coffee") ?? UIImage(),
        .beauty: UIImage(named: "make-up") ?? UIImage(),
        .hobby: UIImage(named: "painting") ?? UIImage(),
        .education: UIImage(named: "book") ?? UIImage(),
        .hospital: UIImage(named: "health-clinic") ?? UIImage()
    ]

    // 플로팅 버튼
    private var floatingButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "plus.circle.fill")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 40)
        configuration.imagePlacement = .all
        configuration.baseForegroundColor = .tintColor
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    lazy var categoryMenuStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 15
        stackView.backgroundColor = .white
        stackView.layer.cornerRadius = 10
        stackView.layer.masksToBounds = true
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        let categories: [PostCategory] = [.restaurant, .cafe, .beauty, .hobby, .education, .hospital]

        categories.forEach { (category) in
            if let image = categoryButtonImages[category] {
                // MARK: - Named Image 사이즈 변경
                let resizeImage = image.resize()
                var configuration = UIButton.Configuration.plain()
                var titleContainer = AttributeContainer()
                titleContainer.font = UIFont.boldSystemFont(ofSize: 15)
                configuration.attributedTitle = AttributedString(category.rawValue, attributes: titleContainer)
                configuration.image = resizeImage
                configuration.image?.withRenderingMode(.alwaysTemplate)
                configuration.imagePadding = 20
                configuration.imagePlacement = .trailing
                let button = UIButton(configuration: configuration)
                button.tintColor = .label
                stackView.addArrangedSubview(button)
                button.addTarget(self, action: #selector(categoryButtonTapped(_:)), for: .touchUpInside)
            }
        }
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(floatingButton)
        addSubview(categoryMenuStackView)

        floatingButton.addTarget(self, action: #selector(tapMenuButton), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        NSLayoutConstraint.activate([
            floatingButton.topAnchor.constraint(equalTo: self.topAnchor).withPriority(.defaultLow),
            floatingButton.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            floatingButton.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            floatingButton.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            categoryMenuStackView.topAnchor.constraint(equalTo: topAnchor).withPriority(.defaultHigh),
            categoryMenuStackView.centerXAnchor.constraint(equalTo: floatingButton.centerXAnchor),
            categoryMenuStackView.bottomAnchor.constraint(equalTo: floatingButton.topAnchor, constant: -10)
        ])
    }

    @objc private func tapMenuButton() {
        UIView.animate(withDuration: 0.1, delay: 0.1, options: .curveEaseInOut) {
            self.categoryMenuStackView.arrangedSubviews.forEach { (button) in
                self.floatingButtonFlag.toggle()
                button.isHidden.toggle()
                self.delegate?.activateDimView(button.isHidden)
            }
        }
        categoryMenuStackView.layoutIfNeeded()
    }

    @objc private func categoryButtonTapped(_ sender: UIButton) {
        if let text = sender.titleLabel?.text {
            textLabelTappedSubject.send(text)
        }
    }
}
