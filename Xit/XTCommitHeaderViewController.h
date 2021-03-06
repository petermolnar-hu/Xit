#import "XTWebViewController.h"

@class XTWindowController;
@class XTRepository;

extern NSString *XTHeaderResizedNotificaiton;
extern NSString *XTHeaderHeightKey;


/**
  Manages a WebView for displaying info about a commit.
 */
@interface XTCommitHeaderViewController : XTWebViewController
{
  NSString *_commitSHA;
  BOOL _expanded;
}

@property XTWindowController *winController;
@property XTRepository *repository;
@property NSString *commitSHA;

+ (NSDateFormatter*)dateFormatter;
- (void)setRepository:(XTRepository*)repository;
- (void)loadHeader;

@end
