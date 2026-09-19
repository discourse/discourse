# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "migrations-importer"
  s.version = "0.0.1"
  s.summary = "Discourse migrations: row importer and uploads importer"
  s.authors = ["Discourse Team"]
  s.required_ruby_version = ">= 3.4"

  s.files = Dir["lib/**/*", "config/**/*"]

  s.add_dependency "migrations-core"
  s.add_dependency "activerecord"
  s.add_dependency "activesupport"
  s.add_dependency "colored2"
  s.add_dependency "i18n"
  s.add_dependency "pg"
  s.add_dependency "zeitwerk"
end
