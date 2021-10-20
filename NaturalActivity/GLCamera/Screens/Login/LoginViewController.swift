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
        loginTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        passwordTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        checkKeychainCredentials()
        updateLoginButtonState()
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
}
