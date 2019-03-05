//
//  ViewController.swift
//  MoyaToken
//
//  Created by Pietro Caselani on 05/03/19.
//  Copyright © 2019 PC. All rights reserved.
//

import UIKit
import Moya
import Result

class ViewController: UIViewController {
  private var tvdbClient: TVDBClient?

  @IBOutlet var textFieldAPIKey: UITextField!

  private func clientUsing(apiKey: String) -> TVDBClient {
    guard let client = tvdbClient else {
      let newClient = TVDBClient(apiKey: apiKey)
      self.tvdbClient = newClient
      return newClient
    }

    return client
  }

  @IBAction func fetchEpisode() {
    guard let apiKey = textFieldAPIKey.text, !apiKey.isEmpty else {
      print("We need the API key")
      return
    }

    let client = clientUsing(apiKey: apiKey)
    getEpisodeDetails(client: client)
  }

  func getEpisodeDetails(client: TVDBClient) {
    client.episodes.request(.episode(id: 297020)) { [weak self] result in
      self?.handle(result: result)
    }
  }

  private func handle(result: Result<Response, MoyaError>) {
    switch result {
    case .failure(let error):
      print("Fail: \(error)")
    case .success(let response):
      let json = try? response.mapJSON()
      let text = json.debugDescription
      print(text)
    }
  }
}

