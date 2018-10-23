import UIKit
import HockeySDK;

class MetricsViewController: UIViewController {
    @IBOutlet weak var metricsStatus: UISegmentedControl!
    @IBOutlet weak var eventNameTextBox: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        metricsStatus?.selectedSegmentIndex = BITHockeyManager.shared().isMetricsManagerDisabled ? 1 : 0;
    }
    
    @IBAction func switchMetricsStatus(_ sender: Any) {
        BITHockeyManager.shared().isMetricsManagerDisabled = metricsStatus.selectedSegmentIndex == 1;
    }
    
    @IBAction func trackEventClicked(_ sender: Any) {
        let manager = BITHockeyManager.shared().metricsManager;
        manager.trackEvent(withName: "testEvent");
    }
    
    @IBAction func trackCustomEventClicked(_ sender: Any) {
        let manager = BITHockeyManager.shared().metricsManager;
        let eventName = eventNameTextBox?.text ?? "";
        if (eventName.isEmpty) {
            let alert = UIAlertController(title: "Incorrect event name", message: "Event name should not be empty", preferredStyle: UIAlertController.Style.alert);
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil));
            self.present(alert, animated: true, completion: nil);
            return;
        }
        
        let properties: [String: String] = [
            "key1": "value1",
            "key2": "value2"
        ];
        
        manager.trackEvent(withName: eventName, properties: properties, measurements: nil);
    }
}
