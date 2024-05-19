import Foundation
import Hummingbird
import ServerData
import SQLiteKit

// Here's our super basic model.
@Model(table: "people") struct Person: Sendable {
	var id: Int?
	var name: String
	var age: Int
}

@main
struct Server {
	static func main() async throws {
		// This encoder is used for generating response bodies
		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted

		// Create a mutable var so we can set logLevel on it, then
		// assign it to a `let` so we don't run into concurrency issues.
		var varlogger = Logger(label: "example")
		varlogger.logLevel = .debug
		let logger = varlogger

		// Get an event loop group provider. I'm not sure if this is the
		// right way to do this.
		let eventLoopGroupProvider = EventLoopGroupProvider.singleton

		// Configure our SQLite database so we can create a ServerData Container
		let config = SQLiteConfiguration(storage: .memory)
		let source = SQLiteConnectionSource(configuration: config)
		let connection = try await source.makeConnection(logger: logger, on: eventLoopGroupProvider.eventLoopGroup.next()).get()
		let database = connection.sql()

		// Create the Container so we can use it to create a PersistentStore for
		// our Person model
		let container = try Container(
			name: "example",
			database: database,
			shutdown: { try! connection.close().wait() }
		)

		// The store is used to save/retrieve model records
		let store = PersistentStore(for: Person.self, container: container)
		// Create the DB if it doesn't exist (which it definitely doesn't since
		// we're just using in memory sqlite.)
		await store.setup()

		// create router and add a single GET /hello route
		let router = Router()

		// Give basic usage
		router.get("") { _, _ -> String in
			"""
			# List people
			curl localhost:8080/people

			# Create a person named Pat who is 40
			curl -XPOST 'localhost:8080/people?name=Pat&age=40'

			# List people who are 40
			curl localhost:8080/people?age=40

			# Get the person with id: 1
			curl localhost:8080/people/1

			"""
		}

		router.get("people") { request, _ -> ByteBuffer in
			let people = if let ageString = request.uri.queryParameters.get("age"), let age = Int(ageString) {
				// If an age is passed in the query params, filter using it
				try await store.list(where: #Predicate<Person> {
					$0.age == age
				})
			} else {
				// Otherwise return everything
				try await store.list()
			}

			let data = try encoder.encode(people)
			return ByteBuffer(data: data)
		}

		router.post("people") { request, _ -> Response in
			// Grab the model values out of the query params
			guard let name = request.uri.queryParameters.get("name"),
			      let ageString = request.uri.queryParameters.get("age"),
			      let age = Int(ageString)
			else {
				return .init(
					status: .unprocessableContent,
					body: .init(byteBuffer: .init(bytes: "Bad parameters".utf8))
				)
			}

			var person = Person(name: name, age: age)

			// Using the inout version of store.save() here so that the `id` field
			// gets populated for the response.
			try await store.save(&person)

			let data = try encoder.encode(person)
			return .init(status: .created, body: .init(byteBuffer: .init(data: data)))
		}

		router.get("people/:id") { request, _ -> Response in
			guard let idString = request.uri.path.components(separatedBy: "/").last,
			      let id = Int(idString)
			else {
				logger.info("did not find person")
				return .init(
					status: .notFound,
					body: .init(byteBuffer: .init(bytes: "Not found".utf8))
				)
			}

			let person = try await store.find(id: id)
			let data = try encoder.encode(person)
			return .init(status: .created, body: .init(byteBuffer: .init(data: data)))
		}

		// create application using router
		let app = Application(
			router: router,
			configuration: .init(address: .hostname("127.0.0.1", port: 8080)),
			eventLoopGroupProvider: eventLoopGroupProvider,
			logger: logger
		)

		// run hummingbird application
		try! await app.runService()
	}
}
