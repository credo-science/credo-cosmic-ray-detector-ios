//
//  UIViewController+Spinner.swift
//  Cosmic Ray
//
//  Created by Maciek Siadkowski on 20/10/2021.
//

import UIKit

var spinnerView : UIView?

extension UIViewController {
    func showSpinner(onView : UIView) {
        let view = UIView.init(frame: onView.bounds)
        view.backgroundColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        let ai = UIActivityIndicatorView.init(style: .whiteLarge)
        ai.startAnimating()
        ai.center = view.center
        
        DispatchQueue.main.async {
            view.addSubview(ai)
            onView.addSubview(view)
        }
        
        spinnerView = view
    }
    
    func removeSpinner() {
        DispatchQueue.main.async {
            spinnerView?.removeFromSuperview()
            spinnerView = nil
        }
    }
}
