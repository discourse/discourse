# frozen_string_literal: true

require_relative "lib/migrations/tooling/version"

Gem::Specification.new do |spec|
  spec.name = "migrations-tooling"
  spec.version = Migrations::Tooling::VERSION
  spec.authors = ["Discourse Team"]
  spec.email = ["team@discourse.org"]
  spec.summary = "Development CLI for Discourse migrations"
  spec.homepage = "https://github.com/discourse/discourse"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "migrations-core"

  spec.add_development_dependency "rspec", "~> 3.12"
end
