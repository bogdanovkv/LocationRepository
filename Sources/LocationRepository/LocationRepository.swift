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

public final class LocationRepository: LocationRepositoryProtocol {
	private let token = "fe17c550289588390f32bb8a4caf562f"
	private enum Endoint: String {
		case currentLocation = "http://www.travelpayouts.com/whereami"
		case allCities = "http://api.travelpayouts.com/data/cities.json"
		case allCountries = "http://api.travelpayouts.com/data/countries.json"
		case allAirports = "http://api.travelpayouts.com/data/airports.json"
	}

	private let networkService: NetworkServiceProtocol
	private let coreDataService: DatabaseServiceProtocol

	public init(networkService: NetworkServiceProtocol,
		 coreDataService: DatabaseServiceProtocol) {
		self.networkService = networkService
		self.coreDataService = coreDataService
	}

	public func loadLocation(_ completion: @escaping (Result<LocationModel, Error>) -> Void) {
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

	public func loadCities(_ completion: @escaping (Result<[CityModel], Error>) -> Void) {
		guard let url = URL(string: Endoint.allCities.rawValue) else {
			return completion(.failure(LocationRepositoryError.urlError))
		}
		let onComplete: (Result<NetworkResponse<[CityDataModel]>, Error>) -> Void = { result in
			do {
				let response = try result.get()
				guard let models = response.data else {
					return completion(.failure(LocationRepositoryError.nilData))
				}
				completion(.success(models.map { $0.cityValue() }))
			} catch {
				completion(.failure(error))
			}
		}
		let request = NetworkRequest(url: url,
									 method: .GET,
									 parameters: [])
		networkService.perfom(request: request, onComplete)
	}

	public func loadCountries(_ completion: @escaping (Result<[CountryModel], Error>) -> Void) {
		guard let url = URL(string: Endoint.allCountries.rawValue) else {
			return completion(.failure(LocationRepositoryError.urlError))
		}
		let request = NetworkRequest(url: url,
									 method: .GET,
									 parameters: [])
		networkService.download(request: request) { result in
			do {
				let url = try result.get()
				let data = try Data(contentsOf: url)
				let models = try JSONDecoder().decode([Throwable<CountryDataModel>].self, from: data)
				completion(.success(models.compactMap({ $0.value?.countryValue() })))
			} catch {
				completion(.failure(error))
			}
		}
	}

	public func loadAirports(_ completion: @escaping (Result<[AirportModel], Error>) -> Void) {
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

	public func save(countries: [CountryModel], completion: @escaping () -> Void) {

		let convertClosure: (CountryModel, StoredObjectProtocol) -> Void = { model, databaseModel in
			databaseModel.setValue(model.name, forKey: "name")
			databaseModel.setValue(model.codeIATA, forKey: "codeIATA")
			if let nameRu = model.nameRu {
				databaseModel.setValue(nameRu, forKey: "nameRu")
			}
		}

		coreDataService.insert(storeId: "CountryManaged", models: countries,
							   convertClosure: convertClosure,
							   completion: completion)
	}

	public func save(cities: [CityModel], completion: @escaping () -> Void) {

		let convertClosure: (CityModel, StoredObjectProtocol) -> Void = { model, databaseModel in
			databaseModel.setValue(model.name, forKey: "name")
			databaseModel.setValue(model.codeIATA, forKey: "codeIATA")
			databaseModel.setValue(model.countryCode, forKey: "countryCode")
			if let nameRu = model.nameRu {
				databaseModel.setValue(nameRu, forKey: "nameRu")
			}
		}

		coreDataService.insert(storeId: "CityManaged", models: cities, convertClosure: convertClosure, completion: completion)
	}

	public func save(airports: [AirportModel], completion: @escaping () -> Void) {

		let convertClosure: (AirportModel, StoredObjectProtocol) -> Void = { model, databaseModel in
			databaseModel.setValue(model.name, forKey: "name")
			databaseModel.setValue(model.code, forKey: "code")
			databaseModel.setValue(model.countryCode, forKey: "countryCode")
			databaseModel.setValue(model.cityCode, forKey: "cityCode")
		}

		coreDataService.insert(storeId: "AirportManaged", models: airports, convertClosure: convertClosure, completion: completion)
	}

	public func getCity(with name: String) -> CityModel? {
		let convertClosure: (StoredObjectProtocol) -> CityModel? = { databaseModel in
			guard let codeIATA: String = databaseModel.value(forKey: "codeIATA"),
				let countryCode: String = databaseModel.value(forKey: "countryCode"),
				let name: String = databaseModel.value(forKey: "name") else { return nil }
			return .init(codeIATA: codeIATA, countryCode: countryCode, name: name, nameRu: databaseModel.value(forKey: "nameRu"))
		}
		let cities = coreDataService.fetch(storeId: "CityManaged", convertClosure: convertClosure,
										   predicate: ["name": name])
		return cities.first
	}

	public func getCountry(with name: String) -> CountryModel? {
		let convertClosure: (StoredObjectProtocol) -> CountryModel? = { databaseModel in
			guard let codeIATA: String = databaseModel.value(forKey: "codeIATA"),
				let name: String = databaseModel.value(forKey: "name") else { return nil }
			return .init(codeIATA: codeIATA, name: name, nameRu: databaseModel.value(forKey: "nameRu"))
		}
		let cities = coreDataService.fetch(storeId: "CountryManaged", convertClosure: convertClosure,
										   predicate: ["name": name])
		return cities.first
	}

	public func getCountries() -> [CountryModel] {
		let convertClosure: (StoredObjectProtocol) -> CountryModel? = { databaseModel in
			guard let codeIATA: String = databaseModel.value(forKey: "codeIATA"),
				  let name: String = databaseModel.value(forKey: "name") else { return nil }
			return .init(codeIATA: codeIATA, name: name, nameRu: databaseModel.value(forKey: "nameRu"))
		}
		let countries = coreDataService.fetch(storeId: "CountryManaged", convertClosure: convertClosure)
		return countries
	}

	public func getCities(for country: CountryModel) -> [CityModel] {
		let convertClosure: (StoredObjectProtocol) -> CityModel? = { databaseModel in
			guard let codeIATA: String = databaseModel.value(forKey: "codeIATA"),
				let countryCode: String = databaseModel.value(forKey: "countryCode"),
				let name: String = databaseModel.value(forKey: "name") else { return nil }
			return .init(codeIATA: codeIATA,
						 countryCode: countryCode,
						 name: name,
						 nameRu: databaseModel.value(forKey: "nameRu"))
		}

		let cities = coreDataService.fetch(storeId: "CityManaged", convertClosure: convertClosure,
										   predicate: ["countryCode": country.codeIATA])
		return cities
	}

	public func getAirports() -> [AirportModel] {
		let convertClosure: (StoredObjectProtocol) -> AirportModel? = { databaseModel in
			guard let code: String = databaseModel.value(forKey: "code"),
				let countryCode: String = databaseModel.value(forKey: "countryCode"),
				let cityCode: String = databaseModel.value(forKey: "cityCode"),
				let name: String = databaseModel.value(forKey: "name") else { return nil }
			return .init(code: code,
						 name: name,
						 countryCode: countryCode,
						 cityCode: cityCode)
		}
		let airpots = coreDataService.fetch(storeId: "AirportManaged", convertClosure: convertClosure)
		return airpots
	}

	public func clearLocations() {
		let group = DispatchGroup()
		group.enter()
		group.enter()
		group.enter()
		coreDataService.deleteAll(storeId: "CityManaged") {
			group.leave()
		}
		coreDataService.deleteAll(storeId: "CountryManaged") {
			group.leave()

		}
		coreDataService.deleteAll(storeId: "AirportManaged") {
			group.leave()

		}
		group.wait()
	}

	private func createDefaultParams() -> [NetworkRequest.Parameter] {
		return [NetworkRequest.Parameter(key: "locale", value: "ru"),
				NetworkRequest.Parameter(key: "callback", value: ""),
				NetworkRequest.Parameter(key: "token", value: token)]
	}
}
