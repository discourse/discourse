# frozen_string_literal: true

require_relative "lib/migrations/core/version"

Gem::Specification.new do |spec|
  spec.name = "migrations-core"
  spec.version = Migrations::Core::VERSION
  spec.authors = ["Discourse Team"]
  spec.email = ["team@discourse.org"]
  spec.summary = "Core library for Discourse migrations tooling"
  spec.homepage = "https://github.com/discourse/discourse"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "bin/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "samovar", "~> 2.3"
  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "zeitwerk", "~> 2.6"

  spec.add_development_dependency "rspec", "~> 3.12"

  spec.bindir = "bin"
  spec.executables = ["disco"]
end
