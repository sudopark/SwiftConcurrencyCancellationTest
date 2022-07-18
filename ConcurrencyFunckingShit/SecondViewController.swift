//
//  SecondViewController.swift
//  ConcurrencyFunckingShit
//
//  Created by sudo.park on 2022/07/19.
//

import Foundation
import UIKit


final class AsyncWorker {
    
    deinit {
        print("deinit async workder")
    }
    
    func makeRandIntVerySlowly() async throws -> Int {
        try await Task.sleep(nanoseconds: 1_000_000_000 * 100) // sleep for 100 seconds
        return Int.random(in: 1...10)
    }
}


final class SecondViewModel {
    
    private let worker: AsyncWorker
    init(worker: AsyncWorker) {
        self.worker = worker
    }
    
    private var task: Task<Void, Error>?
    
    deinit {
        
        print("deinit secondViewModel")
        
        self.task?.cancel()
    }
    
    func makeInt() {
        
        self.task = Task.detached { [weak self] in
            do {
                let int = try await self?.worker.makeRandIntVerySlowly()
                print("int made -> \(int)")
            } catch {
                print("make int error: \(error)")
            }
        }
    }
}


final class SecondViewController: UIViewController {
        
    deinit {
        print("deinit secondViewController")
    }
    
    private var viewModel: SecondViewModel = SecondViewModel(worker: .init())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .red
        
        print("let's make int")
        self.viewModel.makeInt()
    }
}
