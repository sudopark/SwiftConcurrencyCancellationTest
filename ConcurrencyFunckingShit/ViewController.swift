//
//  ViewController.swift
//  ConcurrencyFunckingShit
//
//  Created by sudo.park on 2022/07/19.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showSecondViewController()
        }
    }

    private func showSecondViewController() {
        
        let controller = SecondViewController()
        self.present(controller, animated: true)
    }
}

