//
//  PasswordView.swift
//
//  Created by rain on 4/21/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import UIKit
import LocalAuthentication

public protocol PasswordInputCompleteProtocol: class {
    func passwordInputComplete(_ passwordContainerView: PasswordContainerView, input: String)
    func biometricAuthenticationComplete(_ passwordContainerView: PasswordContainerView, success: Bool, error: Error?)
    func passwordInputCancel(_ passwordContainerView: PasswordContainerView)
}

open class PasswordContainerView: UIView {
    
    //MARK: IBOutlet
    @IBOutlet open var passwordInputViews: [PasswordInputView]!
    @IBOutlet open weak var passwordDotView: PasswordDotView!
    @IBOutlet open weak var deleteButton: UIButton!
    @IBOutlet open weak var touchAuthenticationButton: UIButton!
    
    open var passwordInputComplete: ((String) -> Void)?
    open var biometricAuthenticationComplete: ((Bool, Error?) -> Void)?
    open var passwordInputCancel: (() -> Void)?

    //MARK: Property
    open var deleteButtonTitle: String = "" {
        didSet {
            if !inputString.isEmpty {
                deleteButton.setTitle(deleteButtonTitle, for: .normal)
            }
        }
    }
    
    open var cancelButtonTitle: String = "" {
        didSet {
            if inputString.isEmpty {
                deleteButton.setTitle(cancelButtonTitle, for: .normal)
            }
        }
    }
    
    open weak var delegate: PasswordInputCompleteProtocol?
    fileprivate lazy var biometricAuthenticateContext = LAContext()
    
    fileprivate var inputString: String = "" {
        didSet {
            passwordDotView.inputDotCount = inputString.count
            let buttonTitle = inputString.isEmpty ? cancelButtonTitle : deleteButtonTitle
            deleteButton.setTitle(buttonTitle, for: .normal)
            checkInputComplete()
        }
    }
    
    open var isVibrancyEffect = false {
        didSet {
            configureVibrancyEffect()
        }
    }
    
    open override var tintColor: UIColor! {
        didSet {
            guard !isVibrancyEffect else { return }
            deleteButton.setTitleColor(tintColor, for: UIControl.State())
            passwordDotView.strokeColor = tintColor
            touchAuthenticationButton.tintColor = tintColor
            passwordInputViews.forEach {
                $0.textColor = tintColor
                $0.borderColor = tintColor
            }
        }
    }
    
    open var highlightedColor: UIColor! {
        didSet {
            guard !isVibrancyEffect else { return }
            passwordDotView.fillColor = highlightedColor
            passwordInputViews.forEach {
                $0.highlightBackgroundColor = highlightedColor
            }
        }
    }
    
    open var isBiometricAuthenticationAvailable: Bool {
        return biometricAuthenticateContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    open var touchAuthenticationEnabled = false {
        didSet {
            let enable = (isBiometricAuthenticationAvailable && touchAuthenticationEnabled)
            touchAuthenticationButton.alpha = enable ? 1.0 : 0.0
            touchAuthenticationButton.isUserInteractionEnabled = enable
        }
    }
    
    open var touchAuthenticationReason = "Touch to unlock"
    
    //MARK: AutoLayout
    open var width: CGFloat = 0 {
        didSet {
            self.widthConstraint.constant = width
        }
    }
    fileprivate let kDefaultWidth: CGFloat = 288
    fileprivate let kDefaultHeight: CGFloat = 410
    fileprivate var widthConstraint: NSLayoutConstraint!
    
    fileprivate func configureConstraints() {
        let ratioConstraint = widthAnchor.constraint(equalTo: self.heightAnchor, multiplier: kDefaultWidth / kDefaultHeight)
        self.widthConstraint = widthAnchor.constraint(equalToConstant: kDefaultWidth)
        self.widthConstraint.priority = UILayoutPriority(rawValue: 999)
        NSLayoutConstraint.activate([ratioConstraint, widthConstraint])
    }
    
    //MARK: VisualEffect
    open func rearrangeForVisualEffectView(in vc: UIViewController) {
        self.isVibrancyEffect = true
        self.passwordInputViews.forEach { passwordInputView in
            let label = passwordInputView.label
            label.removeFromSuperview()
            vc.view.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.addConstraints(fromView: label, toView: passwordInputView, constraintInsets: .zero)
        }
    }
    
    //MARK: Init
    open class func create(withDigit digit: Int) -> PasswordContainerView {
        let bundle = Bundle(for: self)
        let nib = UINib(nibName: "PasswordContainerView", bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! PasswordContainerView
        view.passwordDotView.totalDotCount = digit
        return view
    }
    
    open class func create(in stackView: UIStackView, digit: Int) -> PasswordContainerView {
        let passwordContainerView = create(withDigit: digit)
        stackView.addArrangedSubview(passwordContainerView)
        return passwordContainerView
    }
    
    //MARK: Life Cycle
    open override func awakeFromNib() {
        super.awakeFromNib()
        configureConstraints()
        backgroundColor = .clear
        passwordInputViews.forEach {
            $0.delegate = self
        }
        deleteButton.titleLabel?.adjustsFontSizeToFitWidth = true
        deleteButton.titleLabel?.minimumScaleFactor = 0.5
        touchAuthenticationEnabled = true
        
        var image = touchAuthenticationButton.imageView?.image?.withRenderingMode(.alwaysTemplate)
        
        if #available(iOS 11, *) {
            if biometricAuthenticateContext.biometryType == .faceID {
                let bundle = Bundle(for: type(of: self))
                image = UIImage(named: "faceid", in: bundle, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
            }
        }
        
        touchAuthenticationButton.setImage(image, for: UIControl.State())
        touchAuthenticationButton.tintColor = tintColor
    }
    
    //MARK: Input Wrong
    open func wrongPassword() {
        passwordDotView.shakeAnimationWithCompletion {
            self.clearInput()
        }
    }
    
    open func clearInput() {
        inputString = ""
    }
    
    //MARK: IBAction
    @IBAction func deleteInputString(_ sender: AnyObject) {
        guard !inputString.isEmpty else {
            delegate?.passwordInputCancel(self)
            self.passwordInputCancel?()
            return
        }
        guard !passwordDotView.isFull else {
            return
        }
        inputString = String(inputString.dropLast())
    }
    
    @IBAction func touchAuthenticationAction(_ sender: UIButton) {
        touchAuthentication()
    }
    
    open func touchAuthentication() {
        guard isBiometricAuthenticationAvailable else { return }
        biometricAuthenticateContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: touchAuthenticationReason) { (success, error) in
            DispatchQueue.main.async {
                if success {
                    self.passwordDotView.inputDotCount = self.passwordDotView.totalDotCount
                    // instantiate LAContext again for avoiding the situation that PasswordContainerView stay in memory when authenticate successfully
                    self.biometricAuthenticateContext = LAContext()
                }
                
                // delay delegate callback for the user can see passwordDotView input dots filled animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.delegate?.biometricAuthenticationComplete(self, success: success, error: error)
                    self.biometricAuthenticationComplete?(success, error)
                }
            }
        }
    }
}

private extension PasswordContainerView {
    func checkInputComplete() {
        if inputString.count == passwordDotView.totalDotCount {
            delegate?.passwordInputComplete(self, input: inputString)
            passwordInputComplete?(inputString)
        }
    }
    
    func configureVibrancyEffect() {
        let whiteColor = UIColor.white
        let clearColor = UIColor.clear
        //delete button title color
        var titleColor: UIColor!
        //dot view stroke color
        var strokeColor: UIColor!
        //dot view fill color
        var fillColor: UIColor!
        //input view background color
        var circleBackgroundColor: UIColor!
        var highlightBackgroundColor: UIColor!
        var borderColor: UIColor!
        //input view text color
        var textColor: UIColor!
        var highlightTextColor: UIColor!
        
        if isVibrancyEffect {
            //delete button
            titleColor = whiteColor
            //dot view
            strokeColor = whiteColor
            fillColor = whiteColor
            //input view
            circleBackgroundColor = clearColor
            highlightBackgroundColor = whiteColor
            borderColor = clearColor
            textColor = whiteColor
            highlightTextColor = whiteColor
        } else {
            //delete button
            titleColor = tintColor
            //dot view
            strokeColor = tintColor
            fillColor = highlightedColor
            //input view
            circleBackgroundColor = whiteColor
            highlightBackgroundColor = highlightedColor
            borderColor = tintColor
            textColor = tintColor
            highlightTextColor = highlightedColor
        }
        
        deleteButton.setTitleColor(titleColor, for: .normal)
        passwordDotView.strokeColor = strokeColor
        passwordDotView.fillColor = fillColor
        touchAuthenticationButton.tintColor = strokeColor
        passwordInputViews.forEach { passwordInputView in
            passwordInputView.circleBackgroundColor = circleBackgroundColor
            passwordInputView.borderColor = borderColor
            passwordInputView.textColor = textColor
            passwordInputView.highlightTextColor = highlightTextColor
            passwordInputView.highlightBackgroundColor = highlightBackgroundColor
            passwordInputView.circleView.layer.borderColor = UIColor.white.cgColor
            //borderWidth as a flag, will recalculate in PasswordInputView.updateUI()
            passwordInputView.isVibrancyEffect = isVibrancyEffect
        }
    }
}

extension PasswordContainerView: PasswordInputViewTappedProtocol {
    public func passwordInputView(_ passwordInputView: PasswordInputView, tappedString: String) {
        guard inputString.count < passwordDotView.totalDotCount else { return }
        inputString += tappedString
    }
}
