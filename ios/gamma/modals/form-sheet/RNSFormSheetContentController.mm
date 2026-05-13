#import "RNSFormSheetContentController.h"
#import "RNSFormSheetContentView.h"
#import "RNSPresentationSourceProvider.h"

#import <React/RCTAssert.h>
#import <React/RCTLog.h>

@interface RNSFormSheetContentController () <UIAdaptivePresentationControllerDelegate, UIGestureRecognizerDelegate
#if !TARGET_OS_TV
                                             ,
                                             UISheetPresentationControllerDelegate
#endif // !TARGET_OS_TV
                                             >
@end

@implementation RNSFormSheetContentController {
  UITapGestureRecognizer *_Nullable _backdropTapGestureRecognizer;
}

- (instancetype)init
{
  if (self = [super init]) {
    self.modalPresentationStyle = UIModalPresentationFormSheet;
  }
  return self;
}

- (RNSFormSheetContentView *)contentView
{
  RCTAssert([self.view isKindOfClass:[RNSFormSheetContentView class]],
            @"[RNScreens] ContentView must be of type RNSFormSheetContentView");
  return static_cast<RNSFormSheetContentView *>(self.view);
}

#pragma mark - UIKit callbacks

- (void)loadView
{
  self.view = [RNSFormSheetContentView new];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];

  [self.delegate sheetControllerViewDidLayoutSubviews:self];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self attachBackdropTapGestureRecognizer];
}

#pragma mark - Presentation Setup

- (void)prepareForPresentation
{
  // The presentation controller is recreated by UIKit on every present/dismiss cycle.
  // We must assign this delegate before actual presentation
  self.presentationController.delegate = self;
#if !TARGET_OS_TV
  self.sheetPresentationController.delegate = self;
#endif // !TARGET_OS_TV
}

// TODO: @t0maboro - This presentation logic is currently quite primitive.
// We are not entirely safe from rapid conflicting updates, and there are edge cases
// where the presentation state might become desynchronized. Addressing this robustly
// might require an approach similar to the tabs implementation using state provenance,
// which will be handled separately.
// Followup ticket: https://github.com/software-mansion/react-native-screens-labs/issues/1420
- (void)presentFromWindowIfNeeded:(nonnull UIWindow *)window
{
  if (self.presentingViewController != nil) {
    return;
  }

  UIViewController *presentationSourceViewController =
      [RNSPresentationSourceProvider findViewControllerForPresentationInWindow:window];
  if (presentationSourceViewController == nil) {
    RCTLogError(
        @"[RNScreens] Failed to present form sheet: The source view controller cannot be found for target window.");
    return;
  }

  [self prepareForPresentation];
  [presentationSourceViewController presentViewController:self animated:YES completion:nil];
}

- (void)dismissIfNeeded
{
  if (self.presentingViewController == nil) {
    return;
  }
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)presentationController
{
  if (self.preventNativeDismiss) {
    return NO;
  }
  return YES;
}

- (void)presentationControllerDidAttemptToDismiss:(UIPresentationController *)presentationController
{
  [self.delegate sheetControllerDidPreventNativeDismiss:self];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController
{
  [self.delegate sheetControllerDidNativeDismiss:self];
}

#if !TARGET_OS_TV
#pragma mark - UISheetPresentationControllerDelegate

- (void)sheetPresentationControllerDidChangeSelectedDetentIdentifier:
    (UISheetPresentationController *)sheetPresentationController
{
  [self.delegate sheetController:self didChangeDetentIdentifier:sheetPresentationController.selectedDetentIdentifier];
}
#endif // !TARGET_OS_TV

#pragma mark - Backdrop tap handling

- (void)attachBackdropTapGestureRecognizer
{
  UIPresentationController *presentationController = self.presentationController;
  if (presentationController && presentationController.containerView && !_backdropTapGestureRecognizer) {
    _backdropTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(handleBackdropTap:)];
    _backdropTapGestureRecognizer.delegate = self;
    _backdropTapGestureRecognizer.cancelsTouchesInView = NO;
    [presentationController.containerView addGestureRecognizer:_backdropTapGestureRecognizer];
  }
}

- (void)detachBackdropTapGestureRecognizer
{
  [_backdropTapGestureRecognizer.view removeGestureRecognizer:_backdropTapGestureRecognizer];
  _backdropTapGestureRecognizer = nil;
}

- (void)handleBackdropTap:(UITapGestureRecognizer *)gesture
{
  if (gesture.state == UIGestureRecognizerStateRecognized) {
    if (_preventNativeDismiss) {
      [self.delegate sheetControllerDidPreventNativeDismiss:self];
    }
  }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
  if (gestureRecognizer == _backdropTapGestureRecognizer) {
    // When native dismissal is not being prevented, this recognizer should not
    // participate in handling touches to avoid interfering with UIKit.
    if (!_preventNativeDismiss) {
      return NO;
    }

    UIPresentationController *presentationController = self.presentationController;

    // Ignore any touches that land inside the actual sheet content.
    if (presentationController && presentationController.presentedView &&
        [touch.view isDescendantOfView:presentationController.presentedView]) {
      return NO;
    }
    return YES;
  }
  return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  if (gestureRecognizer == _backdropTapGestureRecognizer) {
    return YES;
  }
  return NO;
}

@end
