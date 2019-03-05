import Moya

public protocol TVDBType: TargetType, AccessTokenAuthorizable {}

public extension TVDBType {

  public var baseURL: URL { return URL(string: "https://api.thetvdb.com")! }

  public var headers: [String: String]? { return nil }

  public var method: Moya.Method { return .get }

  public var authorizationType: AuthorizationType { return .bearer }

  public var sampleData: Data { return Data() }
}
