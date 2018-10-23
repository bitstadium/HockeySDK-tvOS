import UIKit

class CrashesViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func hockeySDKCrashAction(_ sender: Any) {
        AppDelegate.manager.crashManager.generateTestCrash()
    }
    
    @IBAction func indexOutOfRangeCrashAction(_ sender: Any) {
        var arr = [1, 3, 5]
        arr[arr.count] = 7
    }
    
    @IBAction func customExceptionAction(_ sender: Any) {
        let name = "customExceptionAndReturnError:"
        let selector = NSSelectorFromString(name)
        
        self.perform(selector)
    }
    
    enum CustomError: Error {
        case runtimeError(String)
    }
    
    @objc func customException() throws {
        print("Throwing error...")
        throw CustomError.runtimeError("Custom message")
    }
}
