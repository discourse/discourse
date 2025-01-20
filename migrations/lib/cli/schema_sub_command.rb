# frozen_string_literal: true

module Migrations::CLI
  class SchemaSubCommand < Thor
    Schema = ::Migrations::Database::Schema

    desc "generate", "Generates the database schema"
    method_option :db, type: :string, default: "intermediate_db", desc: "Name of the database"
    def generate
      db = options[:db]
      config = load_config_file(db)

      puts "Loading schema for #{db.bold}..."
      ::Migrations.load_rails_environment(quiet: true)

      loader = Schema::Loader.new(config[:schema])
      schema = loader.load_schema

      if loader.errors.present?
        loader.errors.each { |error| $stderr.puts "ERROR: ".red << error }
        exit 2
      end

      header = file_header(db)

      schema_file_path = File.expand_path(config.dig(:output, :schema_file), ::Migrations.root_path)

      File.open(schema_file_path, "w") do |schema_file|
        writer = Schema::TableWriter.new(schema_file)
        writer.output_file_header(header)

        schema.each { |table| writer.output_table(table) }
      end

      writer = Schema::ModelWriter.new(config.dig(:output, :models_namespace), header)
      models_path = File.expand_path(config.dig(:output, :models_directory), ::Migrations.root_path)

      schema.each do |table|
        model_file_path = File.join(models_path, Schema::ModelWriter.filename_for(table))
        File.open(model_file_path, "w") { |model_file| writer.output_table(table, model_file) }
      end

      Schema::ModelWriter.format_files(models_path)
    end

    desc "validate", "Validates the schema config file"
    method_option :db, type: :string, default: "intermediate_db", desc: "Name of the database"
    def validate
      db = options[:db]
      config = load_config_file(db)

      puts "Validating configuration for #{db.bold}..."
      ::Migrations.load_rails_environment(quiet: true)

      validator = Schema::ConfigValidator.new
      validator.validate(config)

      if validator.has_errors?
        validator.errors.each { |error| print_error(error) }
        exit(1)
      else
        puts "Configuration file is valid".green
      end
    end

    private

    def relative_config_path(db)
      File.join("config", "#{db}.yml")
    end

    def file_header(db)
      <<~HEADER
          This file is auto-generated from the IntermediateDB schema. To make changes, update
          the "#{relative_config_path(db)}" configuration file and then run `cli schema generate` to
          regenerate this file.
        HEADER
    end

    def load_config_file(db)
      config_path = File.join(::Migrations.root_path, relative_config_path(db))

      if !File.exist?(config_path)
        print_error("Configuration file for #{db} wasn't found at '#{config_path}'")
        exit 1
      end

      YAML.load_file(config_path, symbolize_names: true)
    end

    def print_error(message)
      $stderr.puts "ERROR: ".red + message
    end
  end
end
