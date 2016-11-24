//
//  ViperTransitioning.swift
//
//  Created by Valentin Popkov on 23.11.16.
//  Copyright © 2016. All rights reserved.
//

import Foundation
import UIKit

protocol ViperModuleTransitionHandler: class {
    
    var moduleInput: ViperModuleInput? { get set }
    
    func openModuleUsingSegue(segueIdentifier: String) -> (ViperOpenModulePromise)
}

@objc protocol ViperModuleOutput: class { }

@objc protocol ViperModuleInput: class {
    
    @objc optional func setModuleOutput(_ moduleOutput: ViperModuleOutput?)
}

typealias ViperModuleLinkClosure = (_ moduleInput: ViperModuleInput) -> (ViperModuleOutput?)

class ViperOpenModulePromise {
    
    public var moduleInput: ViperModuleInput? {
        didSet {
            moduleInputWasSet = true;
            self.tryPerformLink()
        }
    }

    private var linkClosure: ViperModuleLinkClosure?
    private var linkClosureWasSet: Bool = false
    private var moduleInputWasSet: Bool = false
    
    public func thenChainUsingClosure(_ linkClosure: ViperModuleLinkClosure?) {
        self.linkClosure = linkClosure
        linkClosureWasSet = true
        tryPerformLink()
    }

    private func tryPerformLink() {
        if (linkClosureWasSet && moduleInputWasSet) {
            performLink()
        }
    }
    
    private func performLink() {
        if let linkClosure = linkClosure,
            let moduleInput = moduleInput {
            let moduleOutput = linkClosure(moduleInput)
            moduleInput.setModuleOutput?(moduleOutput)
        }
    }
}

extension UIViewController: ViperModuleTransitionHandler {
    
    private struct AssociatedKeys {
        static var ModuleInputName = "mmtios_ModuleInputName"
    }
    
    internal var moduleInput: ViperModuleInput? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.ModuleInputName) as? ViperModuleInput
        }
        
        set {
            if let newValue = newValue {
                objc_setAssociatedObject(
                    self,
                    &AssociatedKeys.ModuleInputName,
                    newValue as ViperModuleInput?,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
    }

    func openModuleUsingSegue(segueIdentifier: String) -> (ViperOpenModulePromise) {
        
        let openModulePromise = ViperOpenModulePromise()
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: segueIdentifier, sender: openModulePromise)
        }
        return openModulePromise;
    }
}

extension UIViewController {
    
    open override class func initialize() {
        // make sure this isn't a subclass
        guard self === UIViewController.self else { return }
        swizzling(self)
    }
    
    // MARK: - Method Swizzling
    
    func mmtios_prepare(for segue: UIStoryboardSegue, sender: Any?) {
        self.mmtios_prepare(for: segue, sender: sender)
        
        if (sender as? ViperOpenModulePromise) == nil {
            return
        }
        
        var destinationViewController = segue.destination
        
        if let navigationController = segue.destination as? UINavigationController {
            destinationViewController = navigationController.topViewController!
        }
        
        let openModulePromise = sender as! ViperOpenModulePromise
        openModulePromise.moduleInput = destinationViewController.moduleInput
    }
}

fileprivate let swizzling: (UIViewController.Type) -> () = { viewController in
    
    let originalSelector = #selector(viewController.prepare(for:sender:))
    let swizzledSelector = #selector(viewController.mmtios_prepare(for:sender:))
    
    let originalMethod = class_getInstanceMethod(viewController, originalSelector)
    let swizzledMethod = class_getInstanceMethod(viewController, swizzledSelector)
    
    let didAddMethod = class_addMethod(viewController, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
    
    if didAddMethod {
        class_replaceMethod(viewController, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
