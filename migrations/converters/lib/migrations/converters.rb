# frozen_string_literal: true

require "zeitwerk"

module Migrations
  module Converters
    # Directories under the gem's converters root that are framework
    # infrastructure rather than converter implementations.
    NON_CONVERTER_DIRS = %w[adapter cli].freeze

    def self.root_path
      @root_path ||= File.expand_path("../..", __dir__)
    end

    def self.converters_path
      @converters_path ||= File.join(__dir__, "converters")
    end

    # Where private (closed-source) converters live in the host application.
    def self.private_converters_path
      @private_converters_path ||=
        ENV["MIGRATIONS_PRIVATE_CONVERTERS_PATH"].presence ||
          File.join(Migrations.host_app_root, "migrations", "private", "converters")
    end

    def self.all
      @all_converters ||=
        begin
          public_paths = Dir[File.join(converters_path, "*")]
          private_paths = Dir[File.join(private_converters_path, "*")]
          non_converter_paths = NON_CONVERTER_DIRS.map { |d| File.join(converters_path, d) }
          all_paths = (public_paths - non_converter_paths) + private_paths

          all_paths.each_with_object({}) do |path, hash|
            next unless File.directory?(path)

            name = File.basename(path).downcase
            existing_path = hash[name]

            raise <<~MSG if existing_path
                Duplicate converter name found: #{name}
                  * #{existing_path}
                  * #{path}
              MSG

            hash[name] = path
          end
        end
    end

    def self.names
      all.keys.sort
    end

    def self.path_of(converter_name)
      converter_name = converter_name.downcase
      path = all[converter_name]
      raise "Could not find a converter named '#{converter_name}'" unless path
      path
    end

    def self.default_settings_path(converter_name)
      local_settings_path = File.join(path_of(converter_name), "settings.local.yml")
      return local_settings_path if File.exist?(local_settings_path)

      File.join(path_of(converter_name), "settings.yml")
    end

    def self.loader
      @loader ||=
        begin
          loader = Zeitwerk::Loader.new
          loader.log! if ENV["DEBUG"]
          loader.inflector.inflect("db" => "DB", "id" => "ID", "cli" => "CLI")
          loader.push_dir(converters_path, namespace: Converters)
          loader.ignore(File.join(converters_path, "register.rb"))

          # Each converter directory collapses all of its subdirectories into a
          # single namespace, so that e.g. `discourse/steps/users.rb` defines
          # `Migrations::Converters::Discourse::Users`. This is required by
          # `Migrations::Conversion::Base#steps`, which discovers steps via the
          # converter module's constants.
          #
          # A directory with a same-named `.rb` sibling is an explicit namespace
          # (e.g. `discourse/markdown_scanner/` + `markdown_scanner.rb`) and keeps
          # its nesting, so a converter can group a larger component into files.
          all.each_value do |converter_path|
            Dir[File.join(converter_path, "**", "*")].each do |subdir|
              next unless File.directory?(subdir)
              next if File.exist?("#{subdir}.rb")

              loader.collapse(subdir)
            end
          end

          loader
        end
    end

    def self.setup_loader
      loader.setup
    end
  end
end

Migrations::Converters.setup_loader
