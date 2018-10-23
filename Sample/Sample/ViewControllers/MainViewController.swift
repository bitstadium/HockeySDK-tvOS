import UIKit

class MainViewController: UIViewController {
    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UpdateVersionLabel();
    }
    
    func UpdateVersionLabel() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "";
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "";
        let versionLabelValue = String(format: "Version: %@(%@)", version, build);
        versionLabel?.text = versionLabelValue;
    }
    @IBAction func checkUpdate(_ sender: Any) {
        AppDelegate.manager.updateManager.checkForUpdate()
    }
}
