import Foundation
import Siesta


/// API for getting TeamCity build information.
class XTTeamCityAPI : XTBasicAuthService, XTServiceAPI {
  
  var type: AccountType { return .TeamCity }
  static let rootPath = "/httpAuth/app/rest"
  
  struct Build {
    
    enum Status {
      case Succeeded
      case Failed
      
      init?(string: String)
      {
        switch string {
          case "SUCCESS":
            self = .Succeeded
          case "FAILURE":
            self = .Failed
          default:
            return nil
        }
      }
    }
    
    enum State {
      case Running
      case Finished
      
      init?(string: String)
      {
        switch string {
          case "running":
            self = .Running
          case "finished":
            self = .Finished
          default:
            return nil
        }
      }
    }
    
    struct Attribute {
      static let ID = "id"
      static let BuildType = "buildTypeId"
      static let BuildNumber = "number"
      static let Status = "status"
      static let State = "state"
      static let Running = "running"
      static let Percentage = "percentageComplete"
      static let BranchName = "branchName"
      static let HRef = "href"
      static let WebURL = "webUrl"
    }
    
    let buildType: String?
    let status: Status?
    let state: State?
    let url: NSURL?
    
    init?(element buildElement: NSXMLElement)
    {
      guard buildElement.name == "build"
      else { return nil }
      
      let attributes = buildElement.attributesDict()
      
      self.buildType = attributes[Attribute.BuildType]
      self.status = attributes[Attribute.Status].flatMap { Status(string: $0) }
      self.state = attributes[Attribute.State].flatMap { State(string: $0) }
      self.url = attributes[Attribute.WebURL].flatMap { NSURL(string: $0) }
    }
    
    init?(xml: NSXMLDocument)
    {
      guard let build = xml.rootElement()
      else { return nil }
      
      self.init(element: build)
    }
  }
  
  private(set) var buildTypesStatus = XTServices.Status.NotStarted
  
  /// Maps VCS root ID to repository URL.
  var vcsRootMap = [String: String]()
  /// Maps built type IDs to lists of repository URLs.
  var vcsBuildTypes = [String: [String]]()
  
  init?(user: String, password: String, baseURL: String?)
  {
    guard let baseURL = baseURL,
          let fullBaseURL = NSURLComponents(string: baseURL)
    else { return nil }
    
    fullBaseURL.path = XTTeamCityAPI.rootPath
    
    super.init(user: user, password: password, baseURL: fullBaseURL.string,
               authenticationPath: "/")
    
    configure(description: "xml") {
      $0.config.pipeline[.parsing].add(XMLResponseTransformer(),
                                       contentTypes: [ "*/xml" ])
    }
  }
  
  /// Status of the most recent build of the given branch from any project
  /// and build type.
  func buildStatus(branch: String, buildType: String) -> Resource
  {
    // Look up:
    // - builds?locator=running:any,
    //    buildType:\(buildType),branch:\(branch)
    // - Returns a list of <build href=".."/>, retrieve those
    // If we just pass this to resource(path:), the ? gets encoded.
    let href = "builds/?locator=running:any,branch:\(branch),buildType:\(buildType)"
    let url = NSURL(string: href, relativeToURL: baseURL)
    
    return self.resource(absoluteURL: url)
  }
  
  // Applies the given closure to the build statuses for the given branch and
  // build type, asynchronously if the data is not yet cached.
  func enumerateBuildStatus(branch: String, builtType: String,
                            processor: ([String: String]) -> Void)
  {
    let statusResource = buildStatus(branch, buildType: builtType)
    
    statusResource.useData(self) { (data) in
      guard let xml = data.content as? NSXMLDocument,
            let builds = xml.children?.first?.children
      else { return }
      
      for build in builds {
        guard let buildElement = build as? NSXMLElement
        else { continue }
        
        processor(buildElement.attributesDict())
      }
    }
  }
  
  var vcsRoots: Resource
  { return resource("vcs-roots") }
  
  var projects: Resource
  { return resource("projects") }
  
  var buildTypes: Resource
  { return resource("buildTypes") }
  
  /// A resource for the repo URL of a VCS root. This will be just the URL,
  /// not wrapped in XML.
  func vcsRootURL(vcsRoodID: String) -> Resource
  {
    return resource("vcs-roots/id:\(vcsRoodID)/properties/url")
  }
  
  override func didAuthenticate()
  {
    // - Get VCS roots, build repo URL -> vcs-root id map.
    vcsRoots.useData(self) { (data) in
      guard let xml = data.content as? NSXMLDocument
      else {
        NSLog("Couldn't parse vcs-roots xml")
        self.buildTypesStatus = .Failed(nil)  // TODO: ParseError type
        return
      }
      self.parseVCSRoots(xml)
    }
  }
}

// MARK: VCS

extension XTTeamCityAPI {
  
  /// Returns all the build types that use the given remote.
  func buildTypes(forRemote remoteURL: NSString) -> [String]
  {
    var result = [String]()
    
    for (buildType, urls) in vcsBuildTypes {
      if !urls.filter({ $0 == remoteURL }).isEmpty {
        result.append(buildType)
      }
    }
    return result
  }
  
  private func parseVCSRoots(xml: NSXMLDocument)
  {
    guard let vcsIDs = xml.rootElement()?.childrenAttributes("id")
    else {
      NSLog("Couldn't parse vcs-roots")
      self.buildTypesStatus = .Failed(nil)
      return
    }
    
    var waitingRootCount = vcsIDs.count
    
    vcsRootMap.removeAll()
    for rootID in vcsIDs {
      let repoResource = self.vcsRootURL(rootID)
      
      repoResource.useData(self) { (data) in
        if let repoURL = data.content as? String {
          self.vcsRootMap[rootID] = repoURL
        }
        waitingRootCount -= 1
        if (waitingRootCount == 0) {
          self.getBuildTypes()
        }
      }
    }
  }
  
  private func getBuildTypes()
  {
    buildTypes.useData(self) { (data) in
      guard let xml = data.content as? NSXMLDocument
      else {
        NSLog("Couldn't parse build types xml")
        self.buildTypesStatus = .Failed(nil)
        return
      }
      self.parseBuildTypes(xml)
    }
  }
  
  private func parseBuildTypes(xml: NSXMLDocument)
  {
    guard let hrefs = xml.rootElement()?.childrenAttributes(Build.Attribute.HRef)
    else {
      NSLog("Couldn't get hrefs: \(xml)")
      return
    }
    
    var waitingTypeCount = hrefs.count
    
    for href in hrefs {
      let relativePath = href.stringByRemovingPrefix(XTTeamCityAPI.rootPath)
      
      resource(relativePath).useData(self, closure: { (data) in
        waitingTypeCount -= 1
        defer {
          if waitingTypeCount == 0 {
            self.buildTypesStatus = .Done
          }
        }
        
        guard let xml = data.content as? NSXMLDocument
        else {
          NSLog("Couldn't parse build type xml: \(data.content)")
          self.buildTypesStatus = .Failed(nil)
          return
        }
        
        self.parseBuildType(xml)
      })
    }
  }
  
  private func parseBuildType(xml: NSXMLDocument)
  {
    guard let buildType = xml.children?.first as? NSXMLElement,
          let rootEntries = buildType.elementsForName("vcs-root-entries").first
    else {
      NSLog("Couldn't find root entries: \(xml)")
      self.buildTypesStatus = .Failed(nil)
      return
    }
    guard let buildTypeID = buildType.attributeForName("id")?.stringValue
    else {
      NSLog("No ID for build type: \(xml)")
      return
    }
    
    let vcsIDs = rootEntries.childrenAttributes("id")
    var buildTypeURLs = [String]()
    
    for vcsID in vcsIDs {
      guard let vcsURL = vcsRootMap[vcsID]
      else {
        NSLog("No match for VCS ID \(vcsID)")
        continue
      }
      
      buildTypeURLs.append(vcsURL)
    }
    vcsBuildTypes[buildTypeID] = buildTypeURLs
  }
}
