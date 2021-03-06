//
//  AirportsRepository.swift
//  
//
//  Created by Константин Богданов on 30.04.2021.
//

import LocationRepositoryAbstraction
import NetworkAbstraction
import DatabaseAbstraction
import Foundation

/// Репозиторий работы с аэропортами
final class AirportsRepository: AirportsRepositoryProtocol {

	private let token: String
	private let storeId: String
	private enum Endoint: String {
		case allAirports = "http://api.travelpayouts.com/data/airports.json"
	}

	private let networkService: NetworkServiceProtocol
	private let databaseService: DatabaseServiceProtocol

	/// Инициализатор
	/// - Parameters:
	///   - networkService: сервис работы с сетью
	///   - databaseService: сервис работы с БД
	///   - token: токен для сервиса
	init(networkService: NetworkServiceProtocol,
		 databaseService: DatabaseServiceProtocol,
		 token: String) {
		self.token = token
		storeId = "AirportManaged"
		self.networkService = networkService
		self.databaseService = databaseService
	}

	func loadAirports(_ completion: @escaping (Result<[AirportModel], Error>) -> Void) {
		guard let url = URL(string: Endoint.allAirports.rawValue) else {
			return completion(.failure(LocationRepositoryError.urlError))
		}
		let request = NetworkRequest(url: url,
									 method: .GET,
									 parameters: [])
		networkService.download(request: request) { result in
			do {
				let url = try result.get()
				let data = try Data(contentsOf: url)
				let models = try JSONDecoder().decode([Throwable<AirportDataModel>].self, from: data)
				completion(.success(models.compactMap({ $0.value?.airportValue() })))
			} catch {
				completion(.failure(error))
			}
		}
	}

	func save(airports: [AirportModel], completion: @escaping () -> Void) {
		let convertClosure: (AirportModel, StoredObjectProtocol) -> Void = { model, databaseModel in
			databaseModel.setValue(model.name, forKey: "name")
			databaseModel.setValue(model.code, forKey: "code")
			databaseModel.setValue(model.countryCode, forKey: "countryCode")
			databaseModel.setValue(model.cityCode, forKey: "cityCode")
		}

		databaseService.insert(storeId: storeId,
							   models: airports,
							   convertClosure: convertClosure,
							   completion: completion)
	}

	func getAirports() -> [AirportModel] {
		let convertClosure = createConvertClosure()
		let airpots = databaseService.fetch(storeId: storeId,
											convertClosure: convertClosure)
		return airpots
	}

	func getAirport(by code: String) -> AirportModel? {
		let convertClosure = createConvertClosure()

		let airports = databaseService.fetch(storeId: storeId,
											convertClosure: convertClosure,
											predicate: ["code": code])
		return airports.first
	}

	func getAirportForCity(with codeIATA: String) -> [AirportModel] {
		let convertClosure = createConvertClosure()

		let airports = databaseService.fetch(storeId: storeId,
											convertClosure: convertClosure,
											predicate: ["cityCode": codeIATA])
		return airports
	}

	func getAirportForCountry(with codeIATA: String) -> [AirportModel] {
		let convertClosure = createConvertClosure()

		let airports = databaseService.fetch(storeId: storeId,
											convertClosure: convertClosure,
											predicate: ["countryCode": codeIATA])
		return airports
	}

	func clearAipotrs() {
		let group = DispatchGroup()
		group.enter()
		databaseService.deleteAll(storeId: "AirportManaged") {
			group.leave()

		}
		group.wait()
	}

	private func createConvertClosure() -> (StoredObjectProtocol) -> AirportModel? {
		return { databaseModel in
			guard let code: String = databaseModel.value(forKey: "code"),
				let countryCode: String = databaseModel.value(forKey: "countryCode"),
				let cityCode: String = databaseModel.value(forKey: "cityCode"),
				let name: String = databaseModel.value(forKey: "name") else { return nil }
			return .init(code: code,
						 name: name,
						 countryCode: countryCode,
						 cityCode: cityCode)
		}
	}
}
