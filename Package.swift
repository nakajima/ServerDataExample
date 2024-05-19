// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "ServerDataExample",
	platforms: [.macOS(.v14)],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.executable(
			name: "ServerDataExample",
			targets: ["ServerDataExample"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/nakajima/ServerData.swift", branch: "main"),
		.package(url: "https://github.com/hummingbird-project/hummingbird", branch: "main"),
		.package(url: "https://github.com/vapor/sqlite-kit", branch: "main")
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.executableTarget(
			name: "ServerDataExample",
			dependencies: [
				.product(name: "ServerData", package: "ServerData.swift"),
				.product(name: "SQLiteKit", package: "sqlite-kit"),
				.product(name: "Hummingbird", package: "hummingbird"),
			]
		),
		.testTarget(
			name: "ServerDataExampleTests",
			dependencies: ["ServerDataExample"]
		),
	]
)
