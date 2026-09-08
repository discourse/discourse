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
      resolve_config_defaults(config)

      executor = Executor.new(config, options)
      executor.start
    end

    # Fills in the paths that live next to the IntermediateDB by default, the
    # same way `disco upload` derives them.
    #
    # `files_db`: when it isn't set, default to `files.db` next to the
    # IntermediateDB — the same place `disco upload` writes it — but only when
    # that file actually exists. An absent files DB is the signal for inline
    # upload mode (the uploads step creates uploads straight into the live
    # site), so a derived-but-missing file stays absent and inline mode wins. An
    # explicit `files_db` always attaches, creating the DB if needed.
    #
    # `download_cache_path` (inline mode only): default to a `downloads`
    # directory next to the IntermediateDB when the uploads section omits it.
    def self.resolve_config_defaults(config)
      intermediate_db = config[:intermediate_db]

      if config[:files_db].blank?
        derived = CompanionPaths.files_db(intermediate_db)
        config[:files_db] = derived if File.exist?(derived)
      end

      uploads = config.dig(:config, :uploads)
      if uploads && uploads[:download_cache_path].blank?
        uploads[:download_cache_path] = CompanionPaths.download_cache_path(intermediate_db)
      end
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
