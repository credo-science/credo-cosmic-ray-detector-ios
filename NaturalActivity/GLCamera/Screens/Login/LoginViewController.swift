//
//  LoginViewController.swift
//  Cosmic Ray
//
//  Created by Maciek Siadkowski on 18/10/2021.
//

import UIKit
import Alamofire

class LoginViewController: UIViewController {

    @IBOutlet weak var loginTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loginTextField.delegate = self
        passwordTextField.delegate = self
        loginTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        passwordTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        checkKeychainCredentials()
        updateLoginButtonState()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func checkKeychainCredentials() {
        if let credentials = KeychainManager.shared.getCredentials() {
            performUserLogin(credentials)
        }
    }

    private func updateLoginButtonState() {
        let isLoginButtonEnabled =  !(loginTextField.text?.isEmpty ?? true) && !(passwordTextField.text?.isEmpty ?? true)
        loginButton.isEnabled = isLoginButtonEnabled
        loginButton.alpha = isLoginButtonEnabled ? 1.0 : 0.5
    }

    @IBAction func loginButtonPressed(_ sender: Any) {
        guard let login = loginTextField.text,
              let password = passwordTextField.text else {
            return
        }
        let credentials = Credentials(login: login, password: password)
        performUserLogin(credentials)
    }

    private func performUserLogin(_ credentials: Credentials) {
        self.showSpinner(onView: self.view)
        CredoApi.shared.login(login: credentials.login, password: credentials.password) { result in
            self.removeSpinner()
            switch result {
            case .success(let loginResponse):
                self.handleSuccessLogin(loginResponse, credentials)
            case .failure(let error):
                self.handleErrorLogin(error)
            }
        }
    }
    
    private func handleSuccessLogin(_ logineResponse: LoginResponse, _ credentials: Credentials) {
        KeychainManager.shared.saveCredentials(credentials)
        let glCameraVC = GLCameraViewController()
        glCameraVC.useVideoFrames = true
        gAppD.showWarmup(0)
        self.navigationController?.pushViewController(glCameraVC, animated: true)
    }
    
    private func handleErrorLogin(_ error: LoginError) {
        let errorAlert = UIAlertController(title: "Login failed!", message: error.localizedDescription, preferredStyle: .alert)
        errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(errorAlert, animated: true, completion: nil)
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        updateLoginButtonState()
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if let loginPosY = loginButton.superview?.convert(loginButton.frame, to: nil).origin.y {
                let offset = self.view.frame.height - loginPosY
                if offset < keyboardSize.height {
                    self.view.frame.origin.y -= offset
                }
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
}

// UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == loginTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            textField.resignFirstResponder()
        }
        return true
    }
}
