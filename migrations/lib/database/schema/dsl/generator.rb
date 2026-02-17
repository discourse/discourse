# frozen_string_literal: true

require "prism"

module Migrations::Database::Schema::DSL
  class Generator
    class GenerationError < StandardError
    end

    def initialize(schema_module)
      @schema = schema_module
      @output_config = schema_module.config.output_config
    end

    def generate
      validate_dsl!
      resolved = resolve_schema
      validate_resolved_schema!(resolved)
      generate_sql(resolved)
      generate_enums(resolved)
      generate_models(resolved)
      format_ruby_files!
      resolved
    end

    private

    def validate_dsl!
      errors = Validator.new(@schema).validate

      if errors.any?
        message = "DSL validation failed with #{errors.size} error(s):\n"
        message += errors.map { |e| "  - #{e}" }.join("\n")
        raise GenerationError, message
      end
    end

    def resolve_schema
      SchemaResolver.new(@schema).resolve
    end

    def validate_resolved_schema!(resolved)
      errors = ResolvedSchemaValidator.new(resolved).validate

      if errors.any?
        message = "Resolved schema validation failed with #{errors.size} error(s):\n"
        message += errors.map { |e| "  - #{e}" }.join("\n")
        raise GenerationError, message
      end
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

    CUSTOM_CODE_START = "# -- custom code --"
    CUSTOM_CODE_END = "# -- end custom code --"

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

        case table.model_mode
        when :manual
          next
        when :extended
          custom_code = extract_custom_code(path) || ""
          File.open(path, "w") { |f| writer.output_table(table, f, custom_code:) }
        else
          File.open(path, "w") { |f| writer.output_table(table, f) }
        end
      end
    end

    def extract_custom_code(path)
      return nil unless File.exist?(path)

      content = File.read(path)
      extract_custom_code_with_prism(content) || extract_custom_code_with_markers(content)
    end

    def extract_custom_code_with_prism(content)
      result = Prism.parse(content)
      return nil unless result.success?

      comments = result.comments
      start_comment = comments.find { |comment| comment.slice == CUSTOM_CODE_START }
      return nil unless start_comment

      end_comment =
        comments.find do |comment|
          comment.slice == CUSTOM_CODE_END &&
            comment.location.start_offset > start_comment.location.start_offset
        end
      return nil unless end_comment

      start_offset = line_end_offset(content, start_comment.location.start_offset)
      custom = content[start_offset...end_comment.location.start_offset]
      custom&.strip.presence
    end

    def extract_custom_code_with_markers(content)
      start_idx = content.index(CUSTOM_CODE_START)
      end_idx = content.index(CUSTOM_CODE_END)
      return nil unless start_idx && end_idx

      after_start = content.index("\n", start_idx)
      return nil unless after_start

      custom = content[(after_start + 1)...end_idx]
      custom&.strip.presence
    end

    def line_end_offset(content, start_offset)
      line_end = content.index("\n", start_offset)
      line_end ? line_end + 1 : content.length
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
      db_label = @output_config.models_namespace.split("::").last
      @file_header ||= <<~HEADER
          This file is auto-generated from the #{db_label} schema. To make changes,
          update the configuration files in "config/schema/" and then run
          `bin/cli schema generate` to regenerate this file.
        HEADER
    end
  end
end
