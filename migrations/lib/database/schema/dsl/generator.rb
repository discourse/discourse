# frozen_string_literal: true

require "prism"

module Migrations
  module Database
    module Schema
      module DSL
        class Generator
          CUSTOM_CODE_START = "# -- custom code --"
          CUSTOM_CODE_END = "# -- end custom code --"

          def initialize(schema_module, database: :intermediate_db)
            @schema = schema_module
            @database = database
            @output_config = schema_module.config.output_config
          end

          def generate
            preflight = @schema.preflight(database: @database)
            validate!(preflight.errors)
            resolved = preflight.resolved
            generate_sql(resolved)
            generate_enums(resolved)
            generate_models(resolved)
            format_ruby_files!
            resolved
          end

          private

          def validate!(errors)
            return if errors.empty?

            message =
              "Schema validation failed with #{errors.size} #{"error".pluralize(errors.size)}:\n"
            message += errors.map { |e| "  - #{e}" }.join("\n")
            raise GenerationError, message
          end

          def generate_sql(resolved)
            schema_file = expand_path(@output_config.schema_file)
            FileUtils.mkdir_p(File.dirname(schema_file))

            File.open(schema_file, "w") do |f|
              writer = TableWriter.new(f)
              writer.output_file_header(file_header)
              resolved.tables.each { |table| writer.output_table(table) }
            end
          end

          def generate_enums(resolved)
            enums_dir = expand_path(@output_config.enums_directory)
            FileUtils.mkdir_p(enums_dir)

            writer = EnumWriter.new(@output_config.enums_namespace, file_header)

            resolved.enums.each do |enum|
              filename = EnumWriter.filename_for(enum)
              path = File.join(enums_dir, filename)
              File.open(path, "w") { |f| writer.output_enum(enum, f) }
            end
          end

          def generate_models(resolved)
            models_dir = expand_path(@output_config.models_directory)
            FileUtils.mkdir_p(models_dir)

            writer =
              ModelWriter.new(
                @output_config.models_namespace,
                @output_config.enums_namespace,
                file_header,
              )

            resolved.tables.each do |table|
              filename = ModelWriter.filename_for(table)
              path = File.join(models_dir, filename)

              case table.model_mode
              when :manual
                next
              when :extended
                custom_code = extract_custom_code(path)
                File.open(path, "w") { |f| writer.output_table(table, f, custom_code:) }
              else
                File.open(path, "w") { |f| writer.output_table(table, f) }
              end
            end
          end

          def extract_custom_code(path)
            return nil unless File.exist?(path)

            content = File.read(path)
            result = Prism.parse(content)

            if !result.success?
              errors = result.errors.map { |e| "  - #{e.message} (line #{e.location.start_line})" }
              raise GenerationError, "Failed to parse '#{path}':\n#{errors.join("\n")}"
            end

            comments = result.comments
            start_comment = comments.find { |comment| comment.slice == CUSTOM_CODE_START }
            return nil unless start_comment

            end_comment =
              comments.find do |comment|
                comment.slice == CUSTOM_CODE_END &&
                  comment.location.start_offset > start_comment.location.start_offset
              end
            return nil unless end_comment

            start_byte = start_comment.location.start_offset
            line_end = content.b.index("\n", start_byte)
            start_offset = line_end ? line_end + 1 : content.bytesize
            content.byteslice(start_offset...end_comment.location.start_offset)&.presence
          end

          def format_ruby_files!
            format_directory(@output_config.models_directory)
            format_directory(@output_config.enums_directory)
          end

          def format_directory(relative_path)
            return unless relative_path
            path = expand_path(relative_path)
            Helpers.format_ruby_files(path)
          rescue StandardError
            # formatting is best-effort; generation still succeeds
          end

          def expand_path(relative_path)
            File.expand_path(relative_path, Migrations.root_path)
          end

          def file_header
            @file_header ||=
              begin
                db_label = Helpers.db_label(@output_config.models_namespace)
                <<~HEADER
                  This file is auto-generated from the #{db_label} schema. To make changes,
                  update the configuration files in "migrations/config/schema/" and then run
                  `migrations/bin/cli schema generate` to regenerate this file.
                HEADER
              end
          end
        end
      end
    end
  end
end
