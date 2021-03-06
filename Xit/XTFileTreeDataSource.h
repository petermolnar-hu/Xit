#import <Cocoa/Cocoa.h>
#import "XTFileListDataSourceBase.h"
#import "XTRepository+Parsing.h"

@class XTFileViewController;
@class XTRepository;


/**
  Provides all files from the selected commit's tree, with special icons
  displayed for changed files. Entried are added for deleted files.
 */
@interface XTFileTreeDataSource : XTFileListDataSourceBase
    <XTFileListDataSource, NSOutlineViewDataSource> {
 @private
  NSTreeNode *_root;
}

- (void)reload;

@end


@interface XTCommitTreeItem : XTFileChange

@end
