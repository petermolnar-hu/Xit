import Cocoa

class XTWorkspaceTreeBuilder: NSObject {
  var changes: [String: XTWorkspaceFileStatus]
  
  init(changes: [String: XTWorkspaceFileStatus]) {
    self.changes = changes
    
    super.init()
  }
  
  func treeAtURL(baseURL: NSURL, rootPath: NSString) -> NSTreeNode {
    let rootItem = XTCommitTreeItem(path: baseURL.path!)
    let node = NSTreeNode(representedObject: rootItem)
    let enumerator = NSFileManager.defaultManager().enumeratorAtURL(
        baseURL,
        includingPropertiesForKeys: [ NSURLIsDirectoryKey ],
        options: .SkipsSubdirectoryDescendants,
        errorHandler: nil)
    let rootPathLength = rootPath.length + 1
    
    while let url: NSURL = enumerator?.nextObject() as! NSURL? {
      let urlPath = url.path!
      let path = (urlPath as NSString).substringFromIndex(rootPathLength)
      
      if path == ".git" {
        continue
      }
      
      var childNode: NSTreeNode?
      var isDirectory: AnyObject?
      
      do {
        try url.getResourceValue(&isDirectory, forKey: NSURLIsDirectoryKey)
      }
      catch {
        continue
      }
      if let isDirValue = isDirectory {
        if (isDirValue as! NSNumber).boolValue {
          childNode = self.treeAtURL(url, rootPath: rootPath)
        } else {
          let item = XTCommitTreeItem(path: path)
          
          if let status = self.changes[path] {
            item.change = status.change
            item.unstagedChange = status.unstagedChange
          }
          childNode = NSTreeNode(representedObject: item)
        }
      }
      if childNode != nil {
        node.mutableChildNodes.addObject(childNode!)
      }
    }
    return node
  }
  
  func build(baseURL: NSURL) -> NSTreeNode {
    return self.treeAtURL(baseURL, rootPath: baseURL.path!)
  }
}
