# frozen_string_literal: true

require "bundler/setup"
Bundler.setup

require "active_support"
require "active_support/core_ext"
require "zeitwerk"

require_relative "lib/converters"
require_relative "lib/importer"

module Migrations
  class NoSettingsFound < StandardError
  end

  def self.root_path
    @root_path ||= __dir__
  end

  def self.load_rails_environment(quiet: false)
    message = "Loading Rails environment..."
    print message if !quiet

    rails_root = File.expand_path("..", __dir__)
    # rubocop:disable Discourse/NoChdir
    Dir.chdir(rails_root) do
      begin
        ENV["DISCOURSE_DEV_ALLOW_HTTPS"] = "1" # suppress warning
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
      {
        "cli" => "CLI",
        "id" => "ID",
        "discourse_db" => "DiscourseDB",
        "intermediate_db" => "IntermediateDB",
        "mappings_db" => "MappingsDB",
        "uploads_db" => "UploadsDB",
      },
    )

    loader.push_dir(File.join(root_path, "lib"), namespace: ::Migrations)
    loader.push_dir(File.join(root_path, "lib", "common"), namespace: ::Migrations)

    # All subdirectories of a converter should have the same namespace.
    # Unfortunately `loader.collapse` doesn't work recursively.
    Converters.all.each do |name, converter_path|
      module_name = name.camelize.to_sym
      namespace = Converters.const_set(module_name, Module.new)
      zeitwerk_collapse(loader, namespace, converter_path)
    end

    importer_path = File.join(root_path, "lib", "importer")
    importer_steps_path = File.join(importer_path, "steps")
    importer_base_steps_path = File.join(importer_steps_path, "base")

    # All subdirectories of the importer should share the same namespace, except for steps.
    zeitwerk_collapse(loader, ::Migrations::Importer, importer_path) do |subdirectory|
      !subdirectory.start_with?(importer_steps_path)
    end

    # Ensure all importer step classes share a single namespace across nested subdirectories,
    # but skip `base` directories so abstract/base classes can remain in their own namespace.
    zeitwerk_collapse(loader, ::Migrations::Importer::Steps, importer_steps_path) do |subdirectory|
      !subdirectory.start_with?(importer_base_steps_path)
    end

    loader.setup
  end

  private_class_method def self.zeitwerk_collapse(loader, namespace, parent_path)
    Dir[File.join(parent_path, "**", "*")].each do |subdirectory|
      next if !File.directory?(subdirectory)
      next if block_given? && !yield(subdirectory)

      loader.push_dir(subdirectory, namespace:)
    end
  end

  def self.enable_i18n
    require "i18n"

    locale_glob = File.join(root_path, "config", "locales", "**", "migrations.*.yml")
    I18n.load_path += Dir[locale_glob]
    I18n.backend.load_translations

    # always use English for now
    I18n.default_locale = :en
    I18n.locale = :en
  end

  def self.apply_global_config
    Regexp.timeout = 2
  end
end
