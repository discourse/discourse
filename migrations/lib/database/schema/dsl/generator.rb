# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class Generator
    class GenerationError < StandardError
    end

    def initialize(schema_module)
      @schema = schema_module
      @output_config = schema_module.config.output_config
    end

    def generate
      resolved = resolve_schema
      generate_sql(resolved)
      generate_enums(resolved)
      generate_models(resolved)
      format_ruby_files!
      resolved
    end

    private

    def resolve_schema
      SchemaResolver.new(@schema).resolve
    end

    def generate_sql(resolved)
      schema_file = File.expand_path(@output_config.schema_file, Migrations.root_path)
      FileUtils.mkdir_p(File.dirname(schema_file))

      File.open(schema_file, "w") do |f|
        writer = Migrations::Database::Schema::TableWriter.new(f)
        writer.output_file_header(file_header)
        resolved.tables.each { |table| writer.output_table(table) }
      end
    end

    def generate_enums(resolved)
      enums_dir = File.expand_path(@output_config.enums_directory, Migrations.root_path)
      FileUtils.mkdir_p(enums_dir)

      writer =
        Migrations::Database::Schema::EnumWriter.new(@output_config.enums_namespace, file_header)

      resolved.enums.each do |enum|
        filename = Migrations::Database::Schema::EnumWriter.filename_for(enum)
        path = File.join(enums_dir, filename)
        File.open(path, "w") { |f| writer.output_enum(enum, f) }
      end
    end

    def generate_models(resolved)
      models_dir = File.expand_path(@output_config.models_directory, Migrations.root_path)
      FileUtils.mkdir_p(models_dir)

      writer =
        Migrations::Database::Schema::ModelWriter.new(
          @output_config.models_namespace,
          @output_config.enums_namespace,
          file_header,
        )

      resolved.tables.each do |table|
        filename = Migrations::Database::Schema::ModelWriter.filename_for(table)
        path = File.join(models_dir, filename)
        File.open(path, "w") { |f| writer.output_table(table, f) }
      end
    end

    def format_ruby_files!
      format_directory(@output_config.models_directory)
      format_directory(@output_config.enums_directory)
    end

    def format_directory(relative_path)
      return unless relative_path
      path = File.expand_path(relative_path, Migrations.root_path)
      Migrations::Database::Schema.format_ruby_files(path)
    rescue StandardError
      # formatting is best-effort; generation still succeeds
    end

    def file_header
      @file_header ||= <<~HEADER
          This file is auto-generated from the IntermediateDB schema. To make changes,
          update the configuration files in "config/schema/" and then run
          `bin/cli schema generate` to regenerate this file.
        HEADER
    end
  end
end
