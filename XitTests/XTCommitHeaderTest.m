#import <XCTest/XCTest.h>
#import <WebKit/WebKit.h>
#import "XTCommitHeaderViewController.h"
#import "XTRepository+Parsing.h"
#include "CFRunLoop+Extensions.h"

NSDate *authorDate = nil;
NSDate *commitDate = nil;

@interface XTCommitHeaderTest : XCTestCase
{
  CFRunLoopRef runLoop;
}

@end


@interface XTCommitHeaderViewController (Test)

@property (readonly, copy) NSString *generateHeaderHTML;

@end


@interface FakeGTRepository : NSObject

- (id)lookUpObjectBySHA:(NSString*)sha error:(NSError**)error;

@end


@interface FakeCommit : NSObject

@property NSString *messageSummary;
@property NSString *shortSHA;
@property NSString *SHA;

@end


@interface FakeRepository : NSObject

@property (readonly, strong) FakeGTRepository *gtRepo;

- (BOOL)parseCommit:(NSString *)ref
         intoHeader:(NSDictionary **)header
            message:(NSString **)message
              files:(NSArray **)files;

@end


@implementation XTCommitHeaderTest

- (void)setUp
{
  authorDate = [NSDate date];
  commitDate = [NSDate dateWithTimeInterval:5000 sinceDate:authorDate];
}

- (void)progressFinished:(NSNotification*)note
{
  CFRunLoopStop(runLoop);
}

- (void)testHTML
{
  WebView *webView = [[WebView alloc] init];
  XTCommitHeaderViewController *hvc = [[XTCommitHeaderViewController alloc] init];
  FakeRepository *fakeRepo = [[FakeRepository alloc] init];

  webView.frameLoadDelegate = hvc;
  webView.UIDelegate = hvc;
  hvc.webView = webView;
  hvc.repository = (XTRepository*)fakeRepo;
  hvc.commitSHA = @"blahblah";

  [[NSNotificationCenter defaultCenter]
      addObserver:self
      selector:@selector(progressFinished:)
      name:WebViewProgressFinishedNotification
      object:webView];

  runLoop = CFRunLoopGetCurrent();
  [hvc loadHeader];
  CFRunLoopRunWithTimeout(5);
  runLoop = NULL;
  [[NSRunLoop mainRunLoop] runUntilDate:
      [NSDate dateWithTimeIntervalSinceNow:2]];

  // The result doesn't include the enclosing html tags, so neither does the
  // reference file.
  NSString *html = [webView stringByEvaluatingJavaScriptFromString:
      @"document.getElementsByTagName('html')[0].innerHTML"];
  NSBundle *testBundle =
      [NSBundle bundleWithIdentifier:@"com.uncommonplace.XitTests"];
  NSURL *expectedURL = [testBundle URLForResource:@"expected header"
                                    withExtension:@"html"];
  NSStringEncoding encoding;
  NSError *error = nil;
  NSString *expectedHtmlTemplate =
      [NSString stringWithContentsOfURL:expectedURL
                           usedEncoding:&encoding
                                  error:&error];
  NSDateFormatter *dateFormatter = [XTCommitHeaderViewController dateFormatter];
  NSString *expectedHtml = [NSString stringWithFormat:expectedHtmlTemplate,
      [dateFormatter stringFromDate:authorDate],
      [dateFormatter stringFromDate:commitDate]];
  
  XCTAssertNil(error);

  NSArray *lines = [html componentsSeparatedByString:@"\n"];
  NSArray *expectedLines = [expectedHtml componentsSeparatedByString:@"\n"];

  // Some differences may be due to changes in WebKit.
  XCTAssertEqual([lines count], [expectedLines count]);
  for (NSUInteger i = 0; i < lines.count; ++i)
    XCTAssertEqualObjects(lines[i], expectedLines[i],
                          @"line %lu", (unsigned long)i);
}

@end

@implementation FakeRepository

- (BOOL)parseCommit:(NSString *)ref
         intoHeader:(NSDictionary **)header
            message:(NSString **)message
              files:(NSArray **)files
{
  *header = @{
      XTAuthorNameKey : @"Guy One",
      XTAuthorEmailKey : @"guy1@example.com",
      XTAuthorDateKey : authorDate,
      XTCommitterNameKey : @"Guy Two",
      XTCommitterEmailKey : @"guy2@example.com",
      XTCommitterDateKey : commitDate,
      XTParentSHAsKey : @[ @"1", @"2", @"3" ],
      XTRefsKey : [NSArray array],
      };
  *message = @"Example message";
  if (files != NULL)
    *files = [NSArray array];
  return YES;
}

- (FakeGTRepository*)gtRepo
{
  return [[FakeGTRepository alloc] init];
}

@end

@implementation FakeGTRepository

- (id)lookUpObjectBySHA:(NSString*)sha error:(NSError**)error
{
  FakeCommit *commit = [[FakeCommit alloc] init];

  if ([sha isEqualToString:@"1"])
    commit.messageSummary = @"Alphabet<>";
  if ([sha isEqualToString:@"2"])
    commit.messageSummary = @"Broccoli&";
  if ([sha isEqualToString:@"3"])
    commit.messageSummary = @"Cypress";
  commit.shortSHA = sha;
  commit.SHA = sha;
  return commit;
}

@end

@implementation FakeCommit

@end