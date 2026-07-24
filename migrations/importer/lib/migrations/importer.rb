# frozen_string_literal: true

require "zeitwerk"

module Migrations
  module Importer
    def self.root_path
      @root_path ||= File.expand_path("../..", __dir__)
    end

    def self.execute(options)
      config_path = File.join(root_path, "config", "importer.yml")
      config = YAML.load_file(config_path, symbolize_names: true)

      executor = Executor.new(config, options)
      executor.start
    end

    def self.loader
      @loader ||=
        begin
          loader = Zeitwerk::Loader.new
          loader.log! if ENV["DEBUG"]
          loader.inflector.inflect("cli" => "CLI", "discourse_db" => "DiscourseDB", "id" => "ID")

          importer_dir = File.join(__dir__, "importer")
          loader.push_dir(importer_dir, namespace: Importer)
          loader.ignore(File.join(importer_dir, "register.rb"))
          configure_collapses(loader, importer_dir)

          loader
        end
    end

    # Replicates the previous flat-tree namespace layout:
    #   * `name_finder/` (and any other non-steps, non-uploads directory)
    #     collapses into `Migrations::Importer`
    #   * `steps/` keeps the `Steps` segment; its nested directories collapse
    #     into `Migrations::Importer::Steps`, except `steps/base/` which keeps
    #     its own `Steps::Base` namespace
    #   * `uploads/` keeps its full `Migrations::Importer::Uploads[::Tasks]`
    #     namespace and is never collapsed
    def self.configure_collapses(loader, importer_dir)
      Dir[File.join(importer_dir, "**", "*")].each do |sub|
        next unless File.directory?(sub)

        rel = sub.delete_prefix(importer_dir + "/")

        # uploads/ and cli/ keep their own namespace segment.
        next if rel == "uploads" || rel.start_with?("uploads/")
        next if rel == "cli" || rel.start_with?("cli/")

        if rel == "steps"
          next
        elsif rel.start_with?("steps/")
          next if rel == "steps/base" || rel.start_with?("steps/base/")
          loader.collapse(sub)
        else
          loader.collapse(sub)
        end
      end
    end

    def self.setup_loader
      loader.setup
    end
  end
end

Migrations.register_locale_path(File.join(Migrations::Importer.root_path, "config", "locales"))
Migrations::Importer.setup_loader
