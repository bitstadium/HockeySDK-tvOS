/*
 * Author: Stephan Diederich
 *
 * Copyright (c) 2013-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_AUTHENTICATOR

#import "BITAuthenticationViewController.h"
#import "BITAuthenticator_Private.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"

@interface BITAuthenticationViewController ()<UITextFieldDelegate>
@property (nonatomic, strong) UITextField *emailTextField;
@property (nonatomic, strong) UITextField *passwordTextField;
@property (nonatomic, strong) UIButton *signInButton;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, copy) NSString *password;

@end

@implementation BITAuthenticationViewController

- (instancetype) initWithDelegate:(id<BITAuthenticationViewControllerDelegate>)delegate {
  self = [super init];
  if (self) {
    self.title = BITHockeyLocalizedString(@"HockeyAuthenticatorViewControllerTitle");
    _delegate = delegate;
  }
  return self;
}

#pragma mark - view lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupView];
  [self blockMenuButton];
  [self updateWebLoginButton];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  [self updateBarButtons];
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

#pragma mark - Property overrides
- (void) updateBarButtons {
  if(self.showsLoginViaWebButton) {
    self.navigationItem.rightBarButtonItem = nil;
  } else {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(saveAction:)];
  }
}

- (void) blockMenuButton {
  UITapGestureRecognizer *tapGestureRec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(menuButtonTapped:)];
  tapGestureRec.allowedPressTypes = @[@(UIPressTypeMenu)];
  [self.view addGestureRecognizer:tapGestureRec];
}
- (void) menuButtonTapped:(id)sender {
  if ([self allRequiredFieldsEntered]) {
    [self saveAction:sender];
  } else {
    NSString *message = NSLocalizedString(@"HockeyAuthenticationAuthFieldsMissing", "");
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"OK")
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction * action) {}];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
  }
}

- (void) setShowsLoginViaWebButton:(BOOL)showsLoginViaWebButton {
  if(_showsLoginViaWebButton != showsLoginViaWebButton) {
    _showsLoginViaWebButton = showsLoginViaWebButton;
    if(self.isViewLoaded) {
      [self updateBarButtons];
      [self updateWebLoginButton];
    }
  }
}

- (void) updateWebLoginButton {
  if(self.showsLoginViaWebButton) {
    static const CGFloat kFooterHeight = 60.f;
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,
                                                                     CGRectGetWidth(self.tableView.bounds),
                                                                     kFooterHeight)];
    UIButton *button = [UIButton buttonWithType:kBITButtonTypeSystem];
    [button setTitle:BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerWebLoginButtonTitle") forState:UIControlStateNormal];
    CGSize buttonSize = [button sizeThatFits:CGSizeMake(CGRectGetWidth(self.tableView.bounds),
                                                        kFooterHeight)];
    button.frame = CGRectMake(floorf((CGRectGetWidth(containerView.bounds) - buttonSize.width) / 2.f),
                              floorf((kFooterHeight - buttonSize.height) / 2.f),
                              buttonSize.width,
                              buttonSize.height);
    button.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    if ([UIButton instancesRespondToSelector:(NSSelectorFromString(@"setTintColor:"))]) {
      [button setTitleColor:BIT_RGBCOLOR(0, 122, 255) forState:UIControlStateNormal];
    }
    [containerView addSubview:button];
    [button addTarget:self
               action:@selector(handleWebLoginButton:)
     forControlEvents:UIControlEventPrimaryActionTriggered];
  }
}

- (IBAction) handleWebLoginButton:(id)sender {
  [self.delegate authenticationViewControllerDidTapWebButton:self];
}

- (void)setEmail:(NSString *)email {
  _email = email;
  if(self.isViewLoaded) {
    self.emailTextField.text = email;
  }
}

- (void)setTableViewTitle:(NSString *)viewDescription {
  _tableViewTitle = [viewDescription copy];
}
#pragma mark - UIViewController Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  return YES;
}

#pragma mark - Private methods
- (BOOL)allRequiredFieldsEntered {
  if (self.requirePassword && [self.password length] == 0)
    return NO;
  
  if (![self.email length] || !bit_validateEmail(self.email))
    return NO;
  
  return YES;
}

- (void)userEmailEntered:(id)sender {
  self.email = [(UITextField *)sender text];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

- (void)userPasswordEntered:(id)sender {
  self.password = [(UITextField *)sender text];
  
  self.navigationItem.rightBarButtonItem.enabled = [self allRequiredFieldsEntered];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  NSInteger nextTag = textField.tag + 1;
  
  UIResponder* nextResponder = [self.view viewWithTag:nextTag];
  if (nextResponder) {
    [nextResponder becomeFirstResponder];
  } else {
    if ([self allRequiredFieldsEntered]) {
      if ([textField isFirstResponder])
        [textField resignFirstResponder];
      
      [self saveAction:nil];
    }
  }
  return NO;
}

#pragma mark - Actions
- (void)saveAction:(id)sender {
  [self setLoginUIEnabled:NO];
  
  __weak typeof(self) weakSelf = self;
  [self.delegate authenticationViewController:self
                handleAuthenticationWithEmail:self.email
                                     password:self.password
                                   completion:^(BOOL succeeded, NSError *error) {
                                     if(succeeded) {
                                       //controller should dismiss us shortly..
                                     } else {
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                         
                                          UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                          message:error.localizedDescription
                                          preferredStyle:UIAlertControllerStyleAlert];
                                          
                                          
                                          UIAlertAction *okAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"OK")
                                          style:UIAlertActionStyleCancel
                                          handler:^(UIAlertAction * action) {}];
                                          
                                          [alertController addAction:okAction];
                                          
                                          [weakSelf presentViewController:alertController animated:YES completion:nil];
                                       });
                                     }
                                   }];
}

#pragma mark - UI Setup

- (void) setLoginUIEnabled:(BOOL) enabled {
  [self.emailTextField setEnabled:NO];
  [self.passwordTextField setEnabled:NO];
  [self.signInButton setEnabled:NO];
}

- (void)setupView {
  
  // Title Text
  self.title = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerSignInButtonTitle");

  // Container View
  _containerView = [UIView new];
  
  // E-Mail Input
  _emailTextField = [UITextField new];
  self.emailTextField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerEmailPlaceholder");
  self.emailTextField.text = self.email;
  self.emailTextField.keyboardType = UIKeyboardTypeEmailAddress;
  self.passwordTextField.delegate = self;
  self.emailTextField.returnKeyType = [self requirePassword] ? UIReturnKeyNext : UIReturnKeyDone;
  [self.emailTextField addTarget:self action:@selector(userEmailEntered:) forControlEvents:UIControlEventEditingChanged];
  [self.containerView addSubview:self.emailTextField];
  
  // Password Input
  if (self.requirePassword) {
    _passwordTextField = [UITextField new];
    self.passwordTextField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerPasswordPlaceholder");
    self.passwordTextField.text = self.password;
    self.passwordTextField.keyboardType = UIKeyboardTypeAlphabet;
    self.passwordTextField.returnKeyType = UIReturnKeyDone;
    self.passwordTextField.secureTextEntry = YES;
    self.passwordTextField.delegate = self;
    [self.passwordTextField addTarget:self action:@selector(userPasswordEntered:) forControlEvents:UIControlEventEditingChanged];
    [self.containerView addSubview:self.passwordTextField];
  }

  // Sign Button
  _signInButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [self.signInButton setTitle:BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerSignInButtonTitle") forState:UIControlStateNormal];
  [self.signInButton addTarget:self action:@selector(signInButtonTapped:) forControlEvents:UIControlEventPrimaryActionTriggered];
  [self.containerView addSubview:self.signInButton];
  
  [self.view addSubview:self.containerView];
}

@end

#endif  /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
