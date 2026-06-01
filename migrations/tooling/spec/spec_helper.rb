# frozen_string_literal: true

require "tmpdir"

# Boot the host harness with the cwd at the application root (see migrations-core
# spec_helper for why); Discourse resolves some Zeitwerk ignore paths relative to it.
if ENV["MIGRATIONS_RAILS"]
  rails_root = File.expand_path("../../..", __dir__)
  Dir.chdir(rails_root) { require File.join(rails_root, "spec", "rails_helper") }
end

require "migrations-tooling"

Migrations.enable_i18n
Migrations.apply_global_config

require "rspec-multi-mock"

Dir[File.expand_path("./support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.mock_with MultiMock::Adapter.for(:rspec, :mocha)

  # Specs tagged `:rails` need a booted Rails environment (live DB introspection,
  # plugin manifests). They run in the Rails integration job, not the isolated
  # gem suite.
  config.filter_run_excluding(:rails) unless ENV["MIGRATIONS_RAILS"]
end
