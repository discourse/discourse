# frozen_string_literal: true

require "bundler/setup"
Bundler.setup

require "active_support"
require "active_support/core_ext"
require "zeitwerk"

require_relative "converters"

module Migrations
  class NoSettingsFound < StandardError
  end

  def self.root_path
    @root_path ||= File.expand_path("..", __dir__)
  end

  def self.load_rails_environment(quiet: false)
    message = "Loading Rails environment ..."
    print message if !quiet

    rails_root = File.expand_path("../..", __dir__)
    # rubocop:disable Discourse/NoChdir
    Dir.chdir(rails_root) do
      begin
        require File.join(rails_root, "config/environment")
      rescue LoadError => e
        $stderr.puts e.message
        raise
      end
    end
    # rubocop:enable Discourse/NoChdir

    if !quiet
      print "\r"
      print " " * message.length
      print "\r"
    end
  end

  def self.configure_zeitwerk
    loader = Zeitwerk::Loader.new
    loader.log! if ENV["DEBUG"]

    loader.inflector.inflect(
      { "cli" => "CLI", "intermediate_db" => "IntermediateDB", "uploads_db" => "UploadsDB" },
    )

    loader.push_dir(File.join(::Migrations.root_path, "lib"), namespace: ::Migrations)
    loader.push_dir(File.join(::Migrations.root_path, "lib", "common"), namespace: ::Migrations)

    # All subdirectories of a converter should have the same namespace.
    # Unfortunately `loader.collapse` doesn't work recursively.
    Converters.all.each do |name, converter_path|
      module_name = name.camelize.to_sym
      namespace = ::Migrations::Converters.const_set(module_name, Module.new)

      Dir[File.join(converter_path, "**", "*")].each do |subdirectory|
        next unless File.directory?(subdirectory)
        loader.push_dir(subdirectory, namespace: namespace)
      end
    end

    loader.setup
  end

  def self.enable_i18n
    require "i18n"

    locale_glob = File.join(::Migrations.root_path, "config", "locales", "**", "migrations.*.yml")
    I18n.load_path += Dir[locale_glob]
    I18n.backend.load_translations

    # always use English for now
    I18n.default_locale = :en
    I18n.locale = :en
  end
end
