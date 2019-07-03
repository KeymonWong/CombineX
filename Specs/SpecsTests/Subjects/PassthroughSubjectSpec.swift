import Foundation
import Quick
import Nimble

#if USE_COMBINE
import Combine
#else
import CombineX
#endif

class PassthroughSubjectSpec: QuickSpec {
    
    override func spec() {
        
        // MARK: - Send Values
        describe("Send Values") {

            // MARK: 1.1 should send as many values as the subscriber's demand
            it("should send as many values as the subscriber's demand") {
                let subject = PassthroughSubject<Int, CustomError>()
                
                var subscription: Subscription?
                var once = false
                
                let sub = CustomSubscriber<Int, CustomError>(receiveSubscription: { (s) in
                    subscription = s
                    s.request(.max(2))
                }, receiveValue: { v in
                    if once {
                        return .none
                    } else {
                        once = true
                        return .max(2)  // total 4
                    }
                }, receiveCompletion: { s in
                })
                
                subject.subscribe(sub)
                
                for i in 0..<10 {
                    subject.send(i)
                }
                
                expect(sub.events.count).to(equal(4))
                
                // ask 5 more
                subscription?.request(.max(5))
                
                for i in 0..<10 {
                    subject.send(i)
                }
                
                expect(sub.events.count).to(equal(9))
            }
            
            // MARK: 1.2 should not send values before the subscriber requests
            it("should not send values before the subscriber requests") {
                let subject = PassthroughSubject<Int, CustomError>()
                
                let sub = CustomSubscriber<Int, CustomError>(receiveSubscription: { (s) in
                }, receiveValue: { v in
                    fail("Subscriber should not receive value")
                    return .none
                }, receiveCompletion: { s in
                })
                
                subject.subscribe(sub)
                subject.send(1)
                subject.send(1)
                
                expect(sub.events).to(beEmpty())
            }
            
            // MARK: 1.3 should send completion even if the subscriber hasn't requested
            it("should send completion even if the subscriber hasn't requested") {
                let subject = PassthroughSubject<Int, CustomError>()
                
                let sub = CustomSubscriber<Int, CustomError>(receiveSubscription: { (s) in
                }, receiveValue: { v in
                    return .none
                }, receiveCompletion: { s in
                })
                
                subject.subscribe(sub)
                
                subject.send(completion: .failure(.e0))
                
                guard let last = sub.events.last else {
                    fail("Events should not be empty")
                    return
                }
                expect(last).to(equal(.completion(.failure(.e0))))
            }
            
            // MARK: 1.4 should not send values to subscribers after sending completion
            it("should not send values to subscribers after sending completion") {
                let subject = PassthroughSubject<Int, CustomError>()
                
                let sub = CustomSubscriber<Int, CustomError>(receiveSubscription: { s in
                    s.request(.unlimited)
                }, receiveValue: { v in
                    return .none
                }, receiveCompletion: { c in
                })
 
                subject.subscribe(sub)
                
                subject.send(completion: .finished)
                
                for i in 0..<10 {
                    subject.send(i)
                }
                
                expect(sub.events.count).to(equal(1))
            }
            
            // MARK: 1.5 should send completion if the subscription happens after sending completion
            it("should send completion if the subscription happens after sending completion") {
                let subject = PassthroughSubject<Int, CustomError>()
                subject.send(completion: .finished)
                
                weak var subObj: CustomSubscriber<Int, CustomError>?
                
                do {
                    let sub = CustomSubscriber<Int, CustomError>(receiveSubscription: { s in
                        s.request(.unlimited)
                    }, receiveValue: { v in
                        return .none
                    }, receiveCompletion: { c in
                    })
                    
                    subObj = sub
                    
                    subject.subscribe(sub)
                    
                    expect(sub.events).to(equal([.completion(.finished)]))
                }
                
                expect(subObj).to(beNil())
            }
            
            // MARK: 1.6 should send values to multi-subscribers as their demand
            it("should send values to multi-subscribers as their demand") {
                let subject = PassthroughSubject<Int, Error>()
                
                var subs: [CustomSubscriber<Int, Error>] = []
                let nums = (0..<10).map { _ in Int.random(in: 0..<10) }
                
                for i in nums {
                    let sub = CustomSubscriber<Int, Error>(receiveSubscription: { s in
                        s.request(.max(i))
                    }, receiveValue: { v in
                        return .none
                    }, receiveCompletion: { c in
                    })
                    
                    subject.subscribe(sub)
                    
                    subs.append(sub)
                }
                
                for i in 0..<10 {
                    subject.send(i)
                }
                
                for (i, sub) in zip(nums, subs) {
                    expect(sub.events.count).to(equal(i))
                }
            }
        }
        
        // MARK: - Release Resources
        describe("Release Resources") {
            
            
            
            // MARK: 2.1 should release subscriptions after sending completion
            it("should release subscriptions after sending completion") {
                let pub = PassthroughSubject<Int, Never>()
                
                weak var subscription: AnyObject?
                
                let sub = CustomSubscriber<Int, Never>(receiveSubscription: { (s) in
                    s.request(.max(1))
                    subscription = s as AnyObject
                }, receiveValue: { v in
                    return .none
                }, receiveCompletion: { s in
                })
                
                pub.subscribe(sub)
                
                expect(subscription).toNot(beNil())
                pub.send(completion: .finished)
                expect(subscription).to(beNil())
            }
            
            // MARK: 2.2 should release subscribers after sending completion
            it("should release subscribers after sending completion") {
                let pub = PassthroughSubject<Int, Never>()
                
                weak var subscriptionObj: AnyObject?
                weak var subObj: AnyObject?
                
                do {
                    let sub = CustomSubscriber<Int, Never>(receiveSubscription: { (s) in
                        s.request(.max(1))
                        subscriptionObj = s as AnyObject
                    }, receiveValue: { v in
                        return .none
                    }, receiveCompletion: { c in
                    })
                    subObj = sub
                    
                    pub.subscribe(sub)
                }
                
                expect(subscriptionObj).toNot(beNil())
                expect(subObj).toNot(beNil())
                pub.send(completion: .finished)
                expect(subscriptionObj).to(beNil())
                expect(subObj).to(beNil())
            }
            
            // MARK: 2.3 should release pub and sub after sending completion
            it("should release pub and sub after sending completion") {
                var subscription: Subscription?
                weak var pubObj: PassthroughSubject<Int, Never>?
                weak var subObj: AnyObject?
                
                do {
                    let pub = PassthroughSubject<Int, Never>()
                    pubObj = pub
                    
                    let sub = CustomSubscriber<Int, Never>(receiveSubscription: { (s) in
                        s.request(.max(1))
                        subscription = s
                    }, receiveValue: { v in
                        return .none
                    }, receiveCompletion: { s in
                    })
                    subObj = sub
                    
                    pub.subscribe(sub)
                }
                
                expect(pubObj).toNot(beNil())
                expect(subObj).toNot(beNil())
                
                pubObj?.send(completion: .finished)
                
                expect(pubObj).to(beNil())
                expect(subObj).toNot(beNil())
                
                _ = subscription
            }
            
            // MARK: 2.4 should release pub and sub after cancelling
            it("should release pub and sub after cancelling") {
                var subscription: Subscription?
                weak var pubObj: PassthroughSubject<Int, Never>?
                weak var subObj: AnyObject?
                
                do {
                    let pub = PassthroughSubject<Int, Never>()
                    pubObj = pub
                    
                    let sub = CustomSubscriber<Int, Never>(receiveSubscription: { (s) in
                        s.request(.max(1))
                        subscription = s
                    }, receiveValue: { v in
                        return .none
                    }, receiveCompletion: { s in
                    })
                    subObj = sub
                    
                    pub.subscribe(sub)
                }
                
                expect(pubObj).toNot(beNil())
                expect(subObj).toNot(beNil())
                
                subscription?.cancel()
                
                expect(pubObj).to(beNil())
                expect(subObj).toNot(beNil())
            }
        }
        
        // MARK: - Concurrent
        describe("Concurrent") {
            
            // MARK: * should send value concurrently
            it("should send value concurrently") {
                let pub = PassthroughSubject<Int, Never>()
                
                var enters: [Date?] = [nil, nil, nil]
                var exits: [Date?] = [nil, nil, nil]
                
                let sub = CustomSubscriber<Int, Never>(receiveSubscription: { (s) in
                    s.request(.unlimited)
                }, receiveValue: { v in
                    Thread.sleep(forTimeInterval: 1)
                    return .none
                }, receiveCompletion: { s in
                })
                
                pub.subscribe(sub)
                
                let g = DispatchGroup()
                
                for i in 0..<3 {
                    DispatchQueue.global().async(group: g) {
                        enters[i] = Date()
                        pub.send(i)
                        exits[i] = Date()
                    }
                }
                
                g.wait()
                
                print(enters)
                print(exits)
                
                let before = enters.compactMap { $0 }
                let after = exits.compactMap { $0 }
                
                expect(before.count).to(equal(3))
                expect(after.count).to(equal(3))
                expect(before.max()).to(beLessThan(after.min()))
            }
            
            // MARK: * should send as many values as the subscriber's demand even if these are sent concurrently
            it("should send as many values as the subscriber's demand even if these are sent concurrently 1") {
                let subject = PassthroughSubject<Int, Never>()
                
                let once = Atomic(value: false)
                
                let sub = CustomSubscriber<Int, Never>(receiveSubscription: { (s) in
                    s.request(.max(10))
                }, receiveValue: { v in
                    if once.compareAndStore(expected: false, newVaue: true) {
                        return .max(5)
                    }
                    return .none
                }, receiveCompletion: { c in
                })
                
                subject.subscribe(sub)
                
                let g = DispatchGroup()
                
                15.times { i in
                    DispatchQueue.global().async(group: g) {
                        subject.send(i)
                    }
                }
                
                g.wait()
                
                print(sub.events.count)
                
                print(sub.events)
                expect(sub.events.count).to(equal(15))
            }
            
            // MARK: * should send as many values as the subscriber's demand even if these are sent concurrently
            it("should send as many values as the subscriber's demand even if these are sent concurrently 2") {
                let subject = PassthroughSubject<Int, Never>()
                
                let once = Atomic(value: false)
                
                let sub = CustomSubscriber<Int, Never>(receiveSubscription: { (s) in
                    s.request(.max(10))
                }, receiveValue: { v in
                    if once.compareAndStore(expected: false, newVaue: true) {
                        return .max(5)
                    }
                    return .none
                }, receiveCompletion: { c in
                })
                
                subject.subscribe(sub)
                
                let g = DispatchGroup()
                
                100.times { i in
                    DispatchQueue.global().async(group: g) {
                        subject.send(i)
                    }
                }
                
                g.wait()
                
                print(sub.events.count)
                
                print(sub.events)
                expect(sub.events.count).to(equal(15))
            }
        }
    }
}
