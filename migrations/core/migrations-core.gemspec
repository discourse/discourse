# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "migrations-core"
  s.version = "0.0.1"
  s.summary = "Discourse migrations framework: CLI, UI, schemas, DB infrastructure"
  s.authors = ["Discourse Team"]
  s.required_ruby_version = ">= 3.4"

  s.files = Dir["lib/**/*", "db/**/*", "config/**/*", "bin/*"]
  s.bindir = "bin"
  s.executables = ["disco"]

  s.add_dependency "activesupport"
  s.add_dependency "colored2"
  s.add_dependency "digest-xxhash"
  s.add_dependency "extralite-bundle"
  s.add_dependency "i18n"
  s.add_dependency "json"
  s.add_dependency "lru_redux"
  s.add_dependency "samovar"
  s.add_dependency "unicode-display_width"
  s.add_dependency "zeitwerk"
end
