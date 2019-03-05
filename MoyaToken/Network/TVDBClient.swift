import Moya

final class TVDBClient {
  public lazy var authentication: MoyaProvider<Authentication> = createProvider(forTarget: Authentication.self)
  public lazy var episodes: MoyaProvider<Episodes> = createProvider(forTarget: Episodes.self)

  private let apiKey: String

  private var token: String? // We should persist this value
  private var lastTokenDate: Date? // We should persist this value

  init(apiKey: String) {
    self.apiKey = apiKey
  }

  public var hasValidToken: Bool {
    guard let tokenDate = lastTokenDate else { return false }

    let diff = Date().timeIntervalSince1970 - tokenDate.timeIntervalSince1970

    // If last token is > 23 hours, we should refresh the token
    return diff < 82800
  }

  func createProvider<T: TVDBType>(forTarget target: T.Type) -> MoyaProvider<T> {
    let endpointClosure = createEndpointClosure(for: target)
    let requestClosure = createRequestClosure(for: target)

    let accessTokenPlugin = AccessTokenPlugin.init(tokenClosure: { [weak self] () -> String in
      self?.token ?? ""
    })

    let plugins = [accessTokenPlugin]

    return MoyaProvider<T>(endpointClosure: endpointClosure,
                           requestClosure: requestClosure,
                           plugins: plugins)
  }

  private func createRequestClosure<T: TVDBType>(for target: T.Type) -> MoyaProvider<T>.RequestClosure {
    // If we are authenticating, skip all logic to get or refresh token, so we return the default request mapping
    if target is Authentication.Type { return MoyaProvider<T>.defaultRequestMapping }

    // We are hitting another endpoint, so we should check and refresh the token if necessary.
    // We can't use the default request mapping
    let requestClosure = { [weak self] (endpoint: Endpoint, done: @escaping MoyaProvider.RequestResultClosure) -> Void in
      self?.checkToken(target: target, endpoint: endpoint, done: done)
    }

    return requestClosure
  }

  private func createEndpointClosure<T: TVDBType>(for target: T.Type) -> MoyaProvider<T>.EndpointClosure {
    let endpointClosure = { (target: T) -> Endpoint in
      let endpoint = MoyaProvider.defaultEndpointMapping(for: target)
      let headers = ["Content-type": "application/json",
                     "Accept": "application/vnd.thetvdb.v2.1.2"]
      return endpoint.adding(newHTTPHeaderFields: headers)
    }

    return endpointClosure
  }

  func checkToken<T: TVDBType>(target: T.Type, endpoint: Endpoint, done: @escaping MoyaProvider<T>.RequestResultClosure) {
    guard let request = try? endpoint.urlRequest() else {
      done(.failure(MoyaError.requestMapping(endpoint.url)))
      return
    }

    if token == nil {
      getToken(target, request, endpoint, done) // There is no token available, so we should get one
    } else {
      if hasValidToken {
        done(.success(request)) // We have a valid token, so just let the request proceed
      } else {
        refreshToken(target, request, endpoint, done) // We have a invalid token, we should refresh the token
      }
    }
  }

  private func refreshToken<T: TVDBType>(_ target: T.Type,
                                         _ request: URLRequest,
                                         _ endpoint: Endpoint,
                                         _ done: @escaping MoyaProvider<T>.RequestResultClosure) {
    self.authentication.request(.refreshToken) { result in
      switch result {
      case .success(let response):
        let jsonResponse: Any
        do {
          jsonResponse = try response.mapJSON()
        } catch {
          done(.failure(MoyaError.objectMapping(error, response)))
          return
        }

        guard let json = jsonResponse as? [String: Any] else {
          done(.failure(MoyaError.jsonMapping(response)))
          return
        }

        guard let token = json["token"] as? String else {
          done(.failure(MoyaError.jsonMapping(response)))
          return
        }

        self.token = token

        done(.success(request)) // Token refresh success! So we proceed with the original request
      case .failure(let error):
        done(.failure(MoyaError.underlying(error, nil))) // We couldn't refresh the token
      }
    }
  }

  private func getToken<T: TVDBType>(_ target: T.Type,
                                     _ request: URLRequest,
                                     _ endpoint: Endpoint,
                                     _ done: @escaping MoyaProvider<T>.RequestResultClosure) {
    self.authentication.request(.login(apiKey: self.apiKey)) { result in
      switch result {
      case .success(let response):
        let jsonResponse: Any
        do {
          jsonResponse = try response.mapJSON()
        } catch {
          done(.failure(MoyaError.objectMapping(error, response)))
          return
        }

        guard let json = jsonResponse as? [String: Any] else {
          done(.failure(MoyaError.jsonMapping(response)))
          return
        }

        guard let token = json["token"] as? String else {
          done(.failure(MoyaError.jsonMapping(response)))
          return
        }

        self.token = token
        self.lastTokenDate = Date()

        done(.success(request)) // All good, so we proceed with the original request
      case .failure(let error):
        done(.failure(MoyaError.underlying(error, nil))) // We couldn't get the token
      }
    }
  }
}
