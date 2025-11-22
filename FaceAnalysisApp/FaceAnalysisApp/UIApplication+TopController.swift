import UIKit

extension UIApplication {
    func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseController: UIViewController?
        if let base {
            baseController = base
        } else {
            baseController = connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
        }

        if let nav = baseController as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }

        if let tab = baseController as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }

        if let presented = baseController?.presentedViewController {
            return topViewController(base: presented)
        }

        return baseController
    }
}
