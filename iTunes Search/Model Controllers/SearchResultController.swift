//
//  SearchResultController.swift
//  iTunes Search
//
//  Created by Spencer Curtis on 8/5/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import Foundation

protocol NetworkSessionProtocol {
    func fetch(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void)
}

extension URLSession: NetworkSessionProtocol {
    func fetch(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let dataTask = self.dataTask(with: request, completionHandler: completionHandler)
        dataTask.resume()
    }
}

// Testing version of 'NetworkSessionProtocol'

class MockURLSession: NetworkSessionProtocol {
    
    let data: Data?
    let error: Error?
    init(data: Data?, error: Error?) {
        self.data = data
        self.error = error
    }
    
    func fetch(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        DispatchQueue.global().async {
            completionHandler(self.data, nil, self.error)
        }
    }
}

class SearchResultController {
    
    enum NetworkError: Error {
        case requestURLIsNil
        case dataTaskError
        case noData
        case decodingError(Error)
    }
    
    func performSearch(for searchTerm: String, resultType: ResultType,
                       urlSession: NetworkSessionProtocol,
                       completion: @escaping (Result<[SearchResult], NetworkError>) -> Void) {
        
        // Preparing the parameters for the URL request
        var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        let parameters = ["term": searchTerm,
                          "entity": resultType.rawValue]
        
        // CompactMap -> transforms the individual elements of a collection into some other element type,
        // while ignoring any optionals that return a nil
        // Dict(key, value) -> (URLQueryItems)
        let queryItems = parameters.compactMap { URLQueryItem(name: $0.key, value: $0.value) }
        urlComponents?.queryItems = queryItems
        
        // prevent execution if 'requestURL' is nil
        guard let requestURL = urlComponents?.url else {
            completion(.failure(.requestURLIsNil))
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = HTTPMethod.get.rawValue
        
        
        
        // Begin a network request to the iTunes api
        
        // What type is URLSession?
        // We don't know
        // All we know is that it implements 'NetworkSessionProtocol'
        urlSession.fetch(with: request) { (possibleData, _, possibleError) in
            
            // We're in some background queue
            guard possibleError == nil else {
                NSLog("Error fetching data: \(possibleError!)")
                completion(.failure(.dataTaskError))
                return
            }
            
            // Verify we did receive data
            guard let data = possibleData else {
                completion(.failure(.noData))
                return
            }
            
            do {
                // Decode data received into json
                let jsonDecoder = JSONDecoder()
                let searchResults = try jsonDecoder.decode(SearchResults.self, from: data)
                completion(.success(searchResults.results))
            } catch {
                print("Unable to decode data into object of type [SearchResult]: \(error)")
                completion(.failure(.decodingError(error)))
            }
        }
    }
    
    let baseURL = URL(string: "https://itunes.apple.com/search")!
}
