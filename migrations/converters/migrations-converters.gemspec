# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "migrations-converters"
  s.version = "0.0.1"
  s.summary = "Discourse migrations: public converter implementations"
  s.authors = ["Discourse Team"]
  s.required_ruby_version = ">= 3.4"

  s.files = Dir["lib/**/*"]

  s.add_dependency "migrations-core"
  s.add_dependency "activesupport"
  s.add_dependency "colored2"
  s.add_dependency "i18n"
  s.add_dependency "markbridge", ">= 0.3.0"
  s.add_dependency "pg"
  s.add_dependency "zeitwerk"
end
