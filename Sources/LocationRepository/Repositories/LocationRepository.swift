//
//  LocationRepository.swift
//
//  Created by Константин Богданов on 24.10.2020.
//  Copyright © 2020 Константин Богданов. All rights reserved.
//

import LocationRepositoryAbstraction
import NetworkAbstraction
import DatabaseAbstraction
import Foundation

/// Репозиторий получения местоположения
final class LocationRepository: LocationRepositoryProtocol {
	private let token: String
	private enum Endoint: String {
		case currentLocation = "http://www.travelpayouts.com/whereami"
		case allCountries = "http://api.travelpayouts.com/data/countries.json"
		case allAirports = "http://api.travelpayouts.com/data/airports.json"
	}

	private let networkService: NetworkServiceProtocol

	/// Инициализатор
	/// - Parameters:
	///   - networkService: сервис работы с сетью
	///   - token: токен для сервиса
	init(networkService: NetworkServiceProtocol,
				token: String) {
		self.token = token
		self.networkService = networkService
	}

	func loadLocation(_ completion: @escaping (Result<LocationModel, Error>) -> Void) {
		guard let url = URL(string: Endoint.currentLocation.rawValue) else {
			return completion(.failure(LocationRepositoryError.urlError))
		}

		let onComplete: (Result<NetworkResponse<LocationDataModel>, Error>) -> Void = { result in
			do {
				let response = try result.get()
				guard let model = response.data else {
					return completion(.failure(LocationRepositoryError.nilData))
				}
				completion(.success(model.locationValue()))
			} catch {
				completion(.failure(error))
			}
		}

		let request = NetworkRequest(url: url,
									 method: .GET,
									 parameters: createDefaultParams())
		networkService.perfom(request: request, onComplete)
	}

	// MARK: - Private
	private func createDefaultParams() -> [NetworkRequest.Parameter] {
		return [NetworkRequest.Parameter(key: "locale", value: "en"),
				NetworkRequest.Parameter(key: "callback", value: ""),
				NetworkRequest.Parameter(key: "token", value: token)]
	}
}
