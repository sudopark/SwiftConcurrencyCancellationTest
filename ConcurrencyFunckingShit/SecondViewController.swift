//
//  SecondViewController.swift
//  ConcurrencyFunckingShit
//
//  Created by sudo.park on 2022/07/19.
//

import Foundation
import UIKit

/**
 log
 let's make int
 deinit secondViewController
 deinit secondViewModel
 deinit async workder
 make int error: CancellationError()
 */

/**
 결론 -> 고로 매 aync 함수를 구현하면서 내부에서 Task.isCancelled와 같은 처리를 해줄필요는 없다?
 1. rx를 사용할때도  결국 dispose를 deinit 단계에서 해줘야하듯이 시작점이 되는 detached task 에서는 task cancel을 제대로 해준다는 가정 하에 + withCheckedThrowingContinuation 구문에서 캡처된 인스턴스들 걱정할필요도 없다 -> task가 cancel되면 해제될것임
 2. 취소되었을때 별도 처리가 필요하다면(ex urlSessionTask.cancel) -> withTaskCancellationHandler로 적절히 처리
 */

final class AsyncWorker {
    
    deinit {
        // 6. worker instance가 먼저 해제되게됨
        print("deinit async workder")
    }
    
    func makeRandIntVerySlowly() async throws -> Int {
        // 5. task가 cancel됨에 따라 이미 실행중(여기서는 sleep?) 임에도 불구하고 해당 구문이 끝나게 되며
//        try await Task.sleep(nanoseconds: 1_000_000_000 * 100) // sleep for 100 seconds
        try await Task.sleep(nanoseconds: 1_000_000_000 * 3) // sleep for 3 seconds
        
        let randDelay: UInt64 = (300_000...300_100).randomElement()! * 1_000
        try await Task.sleep(nanoseconds: randDelay) // sleep for rand
        return Int.random(in: 1...10)
    }
}



// 2-2. 이경우 SecondViewModel을 메인엑터로 바꾸고
@MainActor
final class SecondViewModel {
    
    private let worker: AsyncWorker
    init(worker: AsyncWorker) {
        self.worker = worker
    }
    
    private var resultInt: Int?
    private var task: Task<Void, Error>?
    private var task2: Task<Void, Error>?
    private var tasks: [Task<Void, Error>]?
    
    deinit {
        // 3 다행히 vm은 view의 라이프사이클에 맞추어 해제될 수 있고
        print("deinit secondViewModel")
        // 4. 이경우 앞서 detach 시킨 task를 cancel시킴
        
        // 7. task cancel을 안시킨다면 task에 의해 캡처된 worker는 끝날때까지 메모리 해제가 안됨
        // + 그리고 Task 생성시에 vm도 같이 캡처되었다면 역시 메모리 해제 안될거임
        self.task?.cancel()
        self.task2?.cancel()
        self.tasks?.forEach { $0.cancel() }
    }
    
    func makeInt() {
    
        // 1. async 형식이 아닌 vm의 makeInt 메소드에서는 async await 구문을 호출하기 위하여 task의 detached를 이용함
        // 2. detached의 operation closure에서 약한참조로 vm을 참조하도록 하였기에
        self.task = Task.detached { [weak self] in
//        self.task = Task.detached { @MainActor [weak self] in
            // 2-3. task 생성시 클로저를 MainActor로 마킹해서 작업을 메인스레드로 보낼 수 있음
            do {
                let int = try await self?.worker.makeRandIntVerySlowly()
//                print("case1: int made -> \(int)")
                // 2-1. task의 결과로 self.resultInt를 수정시에 race condition이 발생함
//                self?.resultInt = int
            } catch {
                // 7. task 취소로 인하여 여기서 error(CancellationError)가 catch되지만 이미 vm, worker는 해제된 상태이고
                // 8. 해당 operation을 소유하는 주체는 task일것이라 예상(task는 struct)
                print("case1: make int error: \(error)")
            }
        }
        
        self.task2 = Task { [weak self] in
            do {
                let int = try await self?.worker.makeRandIntVerySlowly()
                print("## case2: int made -> \(int)")
                self?.resultInt = int
            }
            catch {
                print("case2: make int error: \(error)")
            }
        }
        
        self.tasks = (0..<100).map { seq -> Task<Void, Error> in
            Task { [weak self] in
                do {
                    let _ = try await self?.worker.makeRandIntVerySlowly()
                    // 2-4.위의 작업들은 vm이 MainActor라서 순차적으로 작업이 진행되지 않더라도 raceCondition은 발생안함
                    self?.resultInt = (self?.resultInt ?? 0) + 1
                    print("case3: int made -> seq: \(seq) \(resultInt)")
                }
                catch {
                    print("case3: make int error: \(error)")
                }
            }
        }
    }
    
//    @MainActor
//    private func increaseInt(_ seq: Int) {
//        self.resultInt = (self.resultInt ?? 0) + 1
//        print("case3: int made -> seq: \(seq) \(resultInt)")
//    }
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
