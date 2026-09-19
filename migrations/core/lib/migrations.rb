# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "zeitwerk"

module Migrations
  class NoSettingsFound < StandardError
  end

  # Each gem registers its `config/locales` directory so that `enable_i18n`
  # loads the union of all translations (and an isolated gem still sees its own).
  def self.locale_load_paths
    @locale_load_paths ||= []
  end

  def self.register_locale_path(dir)
    locale_load_paths << dir if locale_load_paths.exclude?(dir)
  end

  # Root of the `migrations-core` gem. Other gems expose their own root.
  def self.root_path
    @root_path ||= File.expand_path("..", __dir__)
  end

  # Root of the host Discourse application (the repository root). Used to lazily
  # boot Rails and to discover private converters.
  def self.host_app_root
    @host_app_root ||= File.expand_path("../../..", __dir__)
  end

  def self.load_rails_environment(quiet: false)
    message = "Loading Rails environment..."
    print message if !quiet

    rails_root = host_app_root
    # rubocop:disable Discourse/NoChdir
    Dir.chdir(rails_root) do
      ENV["DISCOURSE_DEV_ALLOW_HTTPS"] = "1" # suppress warning
      require File.join(rails_root, "config/environment")
    rescue LoadError => e
      $stderr.puts e.message
      raise
    end
    # rubocop:enable Discourse/NoChdir

    if !quiet
      print "\r"
      print " " * message.length
      print "\r"
    end
  end

  def self.loader
    @loader ||=
      begin
        loader = Zeitwerk::Loader.new
        loader.log! if ENV["DEBUG"]
        configure_inflections(loader)
        loader.push_dir(File.join(__dir__, "migrations"), namespace: Migrations)
        configure_collapses(loader)
        loader
      end
  end

  def self.configure_inflections(loader)
    loader.inflector.inflect(
      {
        "cli" => "CLI",
        "id" => "ID",
        "intermediate_db" => "IntermediateDB",
        "mappings_db" => "MappingsDB",
        "uploads_db" => "UploadsDB",
      },
    )
  end

  # Collapse `common/` into the root `Migrations` namespace, matching the previous
  # flat layout (e.g. `common/enum.rb` => `Migrations::Enum`). Nested directories
  # such as `common/set_store/` keep contributing a namespace segment
  # (`Migrations::SetStore::*`).
  def self.configure_collapses(loader)
    loader.collapse(File.join(__dir__, "migrations", "common"))
  end

  def self.setup_loader
    loader.setup
  end

  def self.enable_i18n
    require "i18n"

    locale_load_paths.each { |dir| I18n.load_path += Dir[File.join(dir, "**", "migrations.*.yml")] }
    I18n.backend.load_translations

    # always use English for now
    I18n.default_locale = :en
    I18n.locale = :en
  end

  def self.apply_global_config
    Regexp.timeout = 2
  end
end

Migrations.register_locale_path(File.join(Migrations.root_path, "config", "locales"))
Migrations.setup_loader
