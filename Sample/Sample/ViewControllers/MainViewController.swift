import UIKit

class MainViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    @IBAction func checkUpdate(_ sender: Any) {
        AppDelegate.manager.updateManager.checkForUpdate()
    }
}
