import UIKit
import HockeySDK

class AuthenticationViewController: UIViewController {
    
    @IBOutlet weak var authType: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
       showAuthType()
    }
    
    @IBAction func anonymAuth(_ sender: Any) {
        changeAuthType(type: BITAuthenticatorIdentificationType.anonymous)
    }
    
    @IBAction func udidAuth(_ sender: Any) {
        print("Not enabled yet")
    }
    
    @IBAction func emailAuth(_ sender: Any) {
        changeAuthType(type: BITAuthenticatorIdentificationType.hockeyAppEmail)
    }
    
    @IBAction func emailAndPasswordAuth(_ sender: Any) {
        changeAuthType(type: BITAuthenticatorIdentificationType.hockeyAppUser)
    }
    
    @IBAction func webAuth(_ sender: Any) {
        print("Not enabled yet")
    }
    
    func changeAuthType(type: BITAuthenticatorIdentificationType){
        AppDelegate.manager.authenticator.cleanupInternalStorage()
        AppDelegate.manager.authenticator.identificationType = type;
        
        if(type == BITAuthenticatorIdentificationType.hockeyAppEmail){
            AppDelegate.manager.authenticator.authenticationSecret = AppDelegate.secret
        }
        AppDelegate.manager.authenticator.authenticateInstallation()
        
        showAuthType()
    }
    
    func showAuthType(){
        switch  AppDelegate.manager.authenticator.identificationType {
        case BITAuthenticatorIdentificationType.anonymous:
            authType.text = "Anonymous"
        case BITAuthenticatorIdentificationType.hockeyAppEmail:
            authType.text = "Email"
        case BITAuthenticatorIdentificationType.hockeyAppUser:
            authType.text = "Email and password"
        default:
            authType.text = "Error"
        }
    }
}
