//
//  File.swift
//  
//
//  Created by Константин Богданов on 30.04.2021.
//

import LocationRepositoryAbstraction
import NetworkAbstraction
import DatabaseAbstraction
import Foundation

/// Репозиторий работы со странами
final class CountriesRepository: CountriesRepositoryProtocol {

	private let token: String
	private let storeId: String
	private enum Endoint: String {
		case allCountries = "http://api.travelpayouts.com/data/countries.json"
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
		storeId = "CountryManaged"
		self.networkService = networkService
		self.databaseService = databaseService
	}

	func loadCountries(_ completion: @escaping (Result<[CountryModel], Error>) -> Void) {
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

	func save(countries: [CountryModel], completion: @escaping () -> Void) {
		let convertClosure: (CountryModel, StoredObjectProtocol) -> Void = { model, databaseModel in
			databaseModel.setValue(model.name, forKey: "name")
			databaseModel.setValue(model.codeIATA, forKey: "codeIATA")
			if let nameRu = model.nameRu {
				databaseModel.setValue(nameRu, forKey: "nameRu")
			}
		}
		databaseService.insert(storeId: storeId,
							   models: countries,
							   convertClosure: convertClosure,
							   completion: completion)
	}

	func getCountry(named: String) -> CountryModel? {
		let convertClosure = createConvertClosure()
		let countries = databaseService.fetch(storeId: storeId, convertClosure: convertClosure,
											  predicate: ["name": named])
		return countries.first
	}

	func getCountry(by codeIATA: String) -> CountryModel? {
		let convertClosure = createConvertClosure()
		let countries = databaseService.fetch(storeId: storeId, convertClosure: convertClosure,
											  predicate: ["codeIATA": codeIATA])
		return countries.first
	}

	func getCountries() -> [CountryModel] {
		let convertClosure = createConvertClosure()
		let countries = databaseService.fetch(storeId: storeId, convertClosure: convertClosure)
		return countries
	}

	func clearCountries() {
		let group = DispatchGroup()
		group.enter()
		databaseService.deleteAll(storeId: storeId) {
			group.leave()
		}
		group.wait()
	}

	private func createConvertClosure() -> (StoredObjectProtocol) -> CountryModel? {
		return { databaseModel in
			guard let codeIATA: String = databaseModel.value(forKey: "codeIATA"),
				  let name: String = databaseModel.value(forKey: "name") else { return nil }
			return .init(codeIATA: codeIATA, name: name, nameRu: databaseModel.value(forKey: "nameRu"))
		}
	}
}
