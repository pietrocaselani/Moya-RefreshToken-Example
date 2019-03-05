import Moya

public enum Episodes {
  case episode(id: Int)
}

extension Episodes: TVDBType {
  public var path: String {
    switch self {
    case .episode(let id): return "episodes/\(id)"
    }
  }

  public var task: Task {
    return .requestPlain
  }
}
