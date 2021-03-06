#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>
#import "Xit-Swift.h"

@class XTRepository;

/**
  QuickLook preview item for binary file previews.
 */
@interface XTPreviewItem : NSObject<QLPreviewItem>

@property(retain, nonatomic) id<XTFileChangesModel> model;
@property(copy, nonatomic) NSString *path;
@property(copy, readonly) NSString *tempFolder;
@property(readonly) NSURL *previewItemURL;

@end
