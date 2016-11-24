import UIKit

public protocol BaseProtocol {
    
}

public class ViperViewController: UIViewController {

    var baseOutput: BaseProtocol?
    var activeSegueBlock:((_ moduleInput: BaseProtocol) -> Void)?

    public func openModule(usingSegue segue: String, chainUsingBlock: @escaping (_ moduleInput: BaseProtocol) -> Void) {
        activeSegueBlock = chainUsingBlock
        performSegue(withIdentifier: segue, sender: self)

    }

    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let activeSegueBlock = activeSegueBlock {
            if let viewController = segue.destination as? ViperViewController {
                activeSegueBlock(viewController.baseOutput!)
            }
            self.activeSegueBlock = nil
        }
    }
}
