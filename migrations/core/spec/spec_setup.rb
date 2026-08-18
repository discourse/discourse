# frozen_string_literal: true

require "fileutils"
require "tempfile"
require "tmpdir"

# Shared bootstrap for the four migration gems' spec suites. Each gem's
# spec_helper delegates here so the Rails boot, i18n, mocking, and support
# wiring live in one place.
module MigrationsSpecSetup
  CORE_SPEC_DIR = __dir__

  # @param gem [String] the gem entrypoint to require (e.g. "migrations-core")
  # @param spec_dir [String] the calling gem's spec directory (__dir__)
  def self.call(gem:, spec_dir:)
    boot_rails(spec_dir) if ENV["MIGRATIONS_RAILS"]

    require gem
    Migrations.enable_i18n
    Migrations.apply_global_config

    require "rspec-multi-mock"

    # Shared support (matchers, helpers, shared examples) lives in the core gem;
    # also load the calling gem's own support, if any.
    load_support(CORE_SPEC_DIR)
    load_support(spec_dir) unless spec_dir == CORE_SPEC_DIR

    RSpec.configure do |config|
      config.mock_with MultiMock::Adapter.for(:rspec, :mocha)

      # Partial stubs on real objects must name a method that actually exists,
      # just like `instance_double`/`class_double` already enforce. Set on the
      # global rspec-mocks config because `mock_with` receives the MultiMock
      # adapter here, not the `:rspec` adapter that normally exposes this
      # setting. The gem suites are mocha-free; Discourse core's own suite
      # never loads this file.
      RSpec::Mocks.configuration.verify_partial_doubles = true

      # Specs tagged `:rails` need a booted Rails environment (live DB
      # introspection, plugin manifests). They run in the Rails integration job,
      # not the isolated gem suite.
      config.filter_run_excluding(:rails) unless ENV["MIGRATIONS_RAILS"]
    end
  end

  # Discourse resolves some autoload-ignore paths (e.g. `lib/freedom_patches` in
  # config/initializers/000-zeitwerk.rb) relative to the working directory, so
  # boot the host harness with the cwd at the application root — the same way the
  # `disco` binary does before loading the Rails environment.
  def self.boot_rails(spec_dir)
    # A dev container may default RAILS_ENV to development, and `rails_helper`
    # only fills it in when unset. Booting anything but test leaves the test
    # gem group unrequired, which surfaces much later as a missing constant
    # from a support file rather than as a wrong-environment error.
    ENV["RAILS_ENV"] = "test"

    rails_root = File.expand_path("../../..", spec_dir)
    Dir.chdir(rails_root) do
      require File.join(rails_root, "spec", "rails_helper")
      warm_asset_processor
    end
  end

  # `AssetProcessor` locates its inputs with a relative glob, so it only builds
  # while the cwd is the application root — and it builds lazily, at the first
  # `PrettyText.cook`, which happens deep inside an example with the cwd back at
  # the gem. Building it here, where the cwd is still right, leaves the memoized
  # context for those examples to use. Cheap after the first run: the built
  # processor is cached on disk.
  def self.warm_asset_processor
    PrettyText.cook("warm up the markdown pipeline")
  end

  def self.load_support(dir)
    Dir[File.join(dir, "support", "**", "*.rb")].sort.each { |file| require file }
  end
end
