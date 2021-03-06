#import <Cocoa/Cocoa.h>

#import "XTTest.h"
#import "XTDocument.h"
#import "XTHistoryViewController.h"
#import "XTRepository.h"
#import "XTSideBarDataSource.h"
#import "XTSideBarOutlineView.h"
#import "XTStatusView.h"
#import "XTRepository+Commands.h"
#import "XTRepository+Parsing.h"
#import <OCMock/OCMock.h>
#include "XTQueueUtils.h"
#import "Xit-Swift.h"

@interface XTHistoryViewControllerTest : XTTest

@property NSDictionary *statusData;

@end

@interface XTHistoryViewControllerTestNoRepo : XCTestCase

@end

@implementation XTHistoryViewControllerTest

@synthesize statusData;

- (void)setUp
{
  [super setUp];
  self.statusData = nil;
  // Don't let change notifications cause unexpected calls.
}

- (void)tearDown
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super tearDown];
}

- (void)testCheckoutBranch
{
  if (![self.repository createBranch:@"b1"]) {
    XCTFail(@"Create Branch 'b1'");
  }

  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:self.repository
                                                  sidebar:mockSidebar];
  XTSideBarItem *branchesGroup = controller.sideBarDS.roots[XTGroupIndexBranches];

  [controller.sideBarDS setRepo:self.repository];
  [[mockSidebar stub] reloadData];
  // Cast because the compiler assumes the wrong setDelegate: method
  [(XTSideBarOutlineView*)[mockSidebar expect] setDelegate:controller.sideBarDS];
  [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:NO];
  [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:NO];
  [[mockSidebar expect] expandItem:nil expandChildren:YES];
  [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:NO];
  [[mockSidebar expect] performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:NO];
  [[mockSidebar expect] expandItem:nil expandChildren:YES];
  [[[mockSidebar expect] andReturn:branchesGroup] parentForItem:OCMOCK_ANY];

  [controller.sideBarDS reload];
  [self waitForRepoQueue];

  // selectBranch
  NSInteger row = 2, noRow = -1;

  [[[mockSidebar expect] andReturn:nil] itemAtRow:XTGroupIndexBranches];
  [[mockSidebar expect] expandItem:OCMOCK_ANY];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)]
      rowForItem:OCMOCK_ANY];
  [[mockSidebar expect] selectRowIndexes:OCMOCK_ANY byExtendingSelection:NO];

  // selectedBranch
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
  [[[mockSidebar expect] andReturn:
          [controller.sideBarDS itemNamed:@"master"
                                  inGroup:XTGroupIndexBranches]] itemAtRow:row];
  [[[mockSidebar expect] andReturn:branchesGroup] parentForItem:OCMOCK_ANY];

  // selectedBranch from checkOutBranch
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(noRow)] contextMenuRow];
  [[[mockSidebar expect] andReturn:
          [controller.sideBarDS itemNamed:@"master"
                                  inGroup:XTGroupIndexBranches]] itemAtRow:row];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
  [[[mockSidebar expect] andReturn:branchesGroup] parentForItem:OCMOCK_ANY];

  [controller.sideBarDS outlineView:mockSidebar
             numberOfChildrenOfItem:nil];  // initialize sidebarDS->outline
  [self waitForRepoQueue];
  XCTAssertEqualObjects([self.repository currentBranch], @"b1", @"");
  [controller selectBranch:@"master"];
  XCTAssertEqualObjects([controller selectedBranch], @"master", @"");
  [controller checkOutBranch:nil];
  [self waitForRepoQueue];
  XCTAssertEqualObjects([self.repository currentBranch], @"master", @"");
}

- (void)makeTwoStashes
{
  XCTAssertTrue([self writeTextToFile1:@"second text"], @"");
  XCTAssertTrue([self.repository saveStash:@"s1" includeUntracked:NO], @"");
  XCTAssertTrue([self writeTextToFile1:@"third text"], @"");
  XCTAssertTrue([self.repository saveStash:@"s2" includeUntracked:NO], @"");
}

- (void)assertStashes:(NSArray *)expectedStashes
{
  NSMutableArray *composedStashes = [NSMutableArray array];
  int i = 0;

  for (NSString *name in expectedStashes)
    [composedStashes addObject:
        [NSString stringWithFormat:@"stash@{%d} On master: %@", i++, name]];

  NSMutableArray *stashes = [NSMutableArray array];

  [self.repository readStashesWithBlock:^(NSString *commit, NSUInteger index, NSString *name) {
    [stashes addObject:name];
  }];
  XCTAssertEqualObjects(stashes, composedStashes, @"");
}

- (void)doStashAction:(SEL)action
            stashName:(NSString *)stashName
      expectedRemains:(NSArray *)expectedRemains
         expectedText:(NSString *)expectedText
{
  [self makeTwoStashes];
  [self assertStashes:@[ @"s2", @"s1" ]];

  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:self.repository
                                                  sidebar:mockSidebar];
  NSInteger stashRow = 2, noRow = -1;

  [controller.sideBarDS setRepo:self.repository];
  [controller.sideBarDS reload];
  [self waitForRepoQueue];

  XTSideBarGroupItem *stashesGroup =
      controller.sideBarDS.roots[XTGroupIndexStashes];
  XTSideBarItem *stashItem =
      [controller.sideBarDS itemNamed:stashName inGroup:XTGroupIndexStashes];

  XCTAssertNotNil(stashItem);
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(noRow)] contextMenuRow];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(stashRow)] selectedRow];
  [[[mockSidebar expect] andReturn:stashesGroup] parentForItem:stashItem];
  [[[mockSidebar expect] andReturn:stashItem] itemAtRow:stashRow];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [controller performSelector:action withObject:nil];
#pragma clang diagnostic pop
  [self waitForRepoQueue];
  [self assertStashes:expectedRemains];

  NSError *error = nil;
  NSString *text = [NSString stringWithContentsOfFile:self.file1Path
                                             encoding:NSASCIIStringEncoding
                                                error:&error];

  XCTAssertNil(error, @"");
  XCTAssertEqualObjects(text, expectedText, @"");
  [mockSidebar verify];
}

- (void)testPopStash1
{
  [self doStashAction:@selector(popStash:)
            stashName:@"On master: s1"
      expectedRemains:@[ @"s2" ]
         expectedText:@"second text"];
}

- (void)testPopStash2
{
  [self doStashAction:@selector(popStash:)
            stashName:@"On master: s2"
      expectedRemains:@[ @"s1" ]
         expectedText:@"third text"];
}

- (void)testApplyStash1
{
  [self doStashAction:@selector(applyStash:)
            stashName:@"On master: s1"
      expectedRemains:@[ @"s2", @"s1" ]
         expectedText:@"second text"];
}

- (void)testApplyStash2
{
  [self doStashAction:@selector(applyStash:)
            stashName:@"On master: s2"
      expectedRemains:@[ @"s2", @"s1" ]
         expectedText:@"third text"];
}

- (void)testDropStash1
{
  [self doStashAction:@selector(dropStash:)
            stashName:@"On master: s1"
      expectedRemains:@[ @"s2" ]
         expectedText:@"some text"];
}

- (void)testDropStash2
{
  [self doStashAction:@selector(dropStash:)
            stashName:@"On master: s2"
      expectedRemains:@[ @"s1" ]
         expectedText:@"some text"];
}

- (void)testMergeText
{
  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:self.repository
                                                  sidebar:mockSidebar];
  XTLocalBranchItem *branchItem =
      [[XTLocalBranchItem alloc] initWithTitle:@"branch"];
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Merge"
                                                action:@selector(mergeBranch:)
                                         keyEquivalent:@""];
  NSInteger row = 1;

  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
  [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];

  XCTAssertTrue([controller validateMenuItem:item]);
  XCTAssertEqualObjects([item title], @"Merge branch into master");
}

- (void)testMergeDisabled
{
  // Merge should be disabled if the selected item is the current branch.
  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:self.repository
                                                  sidebar:mockSidebar];
  XTLocalBranchItem *branchItem =
      [[XTLocalBranchItem alloc] initWithTitle:@"master"];
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Merge"
                                                action:@selector(mergeBranch:)
                                         keyEquivalent:@""];
  NSInteger row = 1;

  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
  [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];

  XCTAssertFalse([controller validateMenuItem:item]);
  XCTAssertEqualObjects([item title], @"Merge");
}

- (void)statusUpdated:(NSNotification *)note
{
  self.statusData = note.userInfo;
}

- (void)testMergeSuccess
{
  NSString *file2Name = @"file2.txt";

  XCTAssertTrue([self.repository createBranch:@"task"]);
  XCTAssertTrue([self commitNewTextFile:file2Name content:@"branch text"]);

  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:self.repository
                                                  sidebar:mockSidebar];
  XTSideBarGroupItem *branchesGroup =
      controller.sideBarDS.roots[XTGroupIndexBranches];
  XTLocalBranchItem *masterItem =
      [[XTLocalBranchItem alloc] initWithTitle:@"master"];
  NSInteger row = 1;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(statusUpdated:)
                                               name:XTStatusNotification
                                             object:self.repository];

  [[[mockSidebar expect] andReturn:branchesGroup] parentForItem:OCMOCK_ANY];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
  [[[mockSidebar expect] andReturn:masterItem] itemAtRow:row];
  [controller mergeBranch:nil];
  WaitForQueue(dispatch_get_main_queue());
  XCTAssertEqualObjects([self.statusData valueForKey:XTStatusTextKey],
                       @"Merged master into task");

  NSString *file2Path = [self.repoPath stringByAppendingPathComponent:file2Name];

  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.file1Path]);
  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:file2Path]);
}

- (void)testMergeFailure
{
  NSError *error = nil;

  XCTAssertTrue([self.repository createBranch:@"task"]);
  XCTAssertTrue([self writeTextToFile1:@"conflicting branch"]);
  XCTAssertTrue([self.repository stageFile:self.file1Path error:&error]);
  XCTAssertTrue([self.repository commitWithMessage:@"conflicting commit"
                                             amend:NO
                                       outputBlock:NULL
                                             error:&error]);

  XCTAssertTrue([self.repository checkout:@"master" error:NULL]);
  XCTAssertTrue([self writeTextToFile1:@"conflicting master"]);
  XCTAssertTrue([self.repository stageFile:self.file1Path error:&error]);
  XCTAssertTrue([self.repository commitWithMessage:@"conflicting commit 2"
                                             amend:NO
                                       outputBlock:NULL
                                             error:&error]);

  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:self.repository
                                                  sidebar:mockSidebar];
  XTSideBarGroupItem *branchesGroup =
      controller.sideBarDS.roots[XTGroupIndexBranches];
  XTLocalBranchItem *masterItem =
      [[XTLocalBranchItem alloc] initWithTitle:@"task"];
  NSInteger row = 1;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(statusUpdated:)
                                               name:XTStatusNotification
                                             object:self.repository];

  [[[mockSidebar expect] andReturn:branchesGroup] parentForItem:OCMOCK_ANY];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] selectedRow];
  [[[mockSidebar expect] andReturn:masterItem] itemAtRow:row];
  [controller mergeBranch:nil];
  WaitForQueue(dispatch_get_main_queue());
  XCTAssertEqualObjects([self.statusData valueForKey:XTStatusTextKey],
                       @"Merge failed");
}

@end

@implementation XTHistoryViewControllerTestNoRepo

- (void)testDeleteCurrentBranch
{
  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  id mockRepo = [OCMockObject mockForClass:[XTRepository class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:mockRepo
                                                  sidebar:mockSidebar];
  NSMenuItem *menuItem =
      [[NSMenuItem alloc] initWithTitle:@"Delete"
                                 action:@selector(deleteBranch:)
                          keyEquivalent:@""];
  NSString *branchName = @"master";
  XTLocalBranchItem *branchItem =
      [[XTLocalBranchItem alloc] initWithTitle:branchName];
  NSInteger row = 1;
  BOOL isWriting = NO;

  [[[mockRepo expect] andReturnValue:OCMOCK_VALUE(isWriting)] isWriting];
  [[[mockRepo expect] andReturn:branchName] currentBranch];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
  [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];
  XCTAssertFalse([controller validateMenuItem:menuItem]);
  [mockRepo verify];
  [mockSidebar verify];
}

- (void)testDeleteOtherBranch
{
  id mockSidebar = [OCMockObject mockForClass:[XTSideBarOutlineView class]];
  id mockRepo = [OCMockObject mockForClass:[XTRepository class]];
  XTHistoryViewController *controller =
      [[XTHistoryViewController alloc] initWithRepository:mockRepo
                                                  sidebar:mockSidebar];
  NSMenuItem *menuItem =
      [[NSMenuItem alloc] initWithTitle:@"Delete"
                                 action:@selector(deleteBranch:)
                          keyEquivalent:@""];
  NSString *clickedBranchName = @"topic";
  NSString *currentBranchName = @"master";
  XTLocalBranchItem *branchItem =
      [[XTLocalBranchItem alloc] initWithTitle:clickedBranchName];
  NSInteger row = 1;
  BOOL isWriting = NO;

  [[[mockRepo expect] andReturnValue:OCMOCK_VALUE(isWriting)] isWriting];
  [[[mockRepo expect] andReturn:currentBranchName] currentBranch];
  [[[mockSidebar expect] andReturnValue:OCMOCK_VALUE(row)] contextMenuRow];
  [[[mockSidebar expect] andReturn:branchItem] itemAtRow:row];
  XCTAssertTrue([controller validateMenuItem:menuItem]);
  [mockRepo verify];
  [mockSidebar verify];
}

@end
