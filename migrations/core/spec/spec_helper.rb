# frozen_string_literal: true

require "tempfile"
require "tmpdir"

# When MIGRATIONS_RAILS is set (the integration job, run via the host app's
# bundle), boot the full Discourse test harness so that :rails-tagged specs can
# run. The default, isolated suite runs without Rails.
#
# Discourse resolves some autoload-ignore paths (e.g. `lib/freedom_patches` in
# config/initializers/000-zeitwerk.rb) relative to the working directory, so boot
# the host harness with the cwd at the application root — the same way the `disco`
# binary does before loading the Rails environment.
if ENV["MIGRATIONS_RAILS"]
  rails_root = File.expand_path("../../..", __dir__)
  Dir.chdir(rails_root) { require File.join(rails_root, "spec", "rails_helper") }
end

require "migrations-core"

Migrations.enable_i18n
Migrations.apply_global_config

require "rspec-multi-mock"

Dir[File.expand_path("./support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.mock_with MultiMock::Adapter.for(:rspec, :mocha)
  config.filter_run_excluding(:rails) unless ENV["MIGRATIONS_RAILS"]
end
