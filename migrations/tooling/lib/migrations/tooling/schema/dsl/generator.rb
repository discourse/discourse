# frozen_string_literal: true

require "prism"

module Migrations
  module Tooling
    module Schema
      module DSL
        class Generator
          CUSTOM_CODE_START = "# -- custom code --"
          CUSTOM_CODE_END = "# -- end custom code --"

          # Files deleted by the last `generate` run, relative to the output
          # root.
          attr_reader :deleted_files

          # `output_root` overrides where the generated files are written
          # (defaults to the repository root). Custom code of extended models
          # is always read from the committed files, so generating into a
          # temporary directory produces the same output as generating
          # in place.
          def initialize(schema_module, database: :intermediate_db, output_root: nil)
            @schema = schema_module
            @database = database
            @output_config = schema_module.config.output_config
            @output_root = output_root || Migrations.root_path
            @deleted_files = []
          end

          def generate
            preflight = @schema.preflight(database: @database)
            validate!(preflight.errors)
            resolved = preflight.resolved
            generate_sql(resolved)
            generate_enums(resolved)
            generate_models(resolved)
            delete_stale_files(resolved)
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
                custom_code =
                  extract_custom_code(
                    File.join(source_path(@output_config.models_directory), filename),
                  )
                File.open(path, "w") { |f| writer.output_table(table, f, custom_code:) }
              else
                File.open(path, "w") { |f| writer.output_table(table, f) }
              end
            end
          end

          # Deletes previously generated files that generation no longer
          # produces, e.g. the model of a table that was removed from the
          # config. Only files carrying the auto-generated header are
          # touched; hand-written (manual) models don't have it.
          def delete_stale_files(resolved)
            expected = GeneratedFiles.expected_paths(resolved, @output_config, @output_root)

            GeneratedFiles
              .stale_paths(@output_config, @output_root, expected)
              .each do |path|
                File.delete(path)
                @deleted_files << display_path(path)
              end
          end

          def display_path(path)
            relative = Pathname.new(path).relative_path_from(@output_root).to_s
            relative.start_with?("..") ? path : relative
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
            # start_comment is a whole-line comment and end_comment sits on a
            # later line, so the newline ending the start marker's line always
            # exists before end_comment: `index` never returns nil here, and the
            # slice always covers a real (possibly empty) range, never nil.
            line_end = content.b.index("\n", start_byte)
            start_offset = line_end + 1
            content.byteslice(start_offset...end_comment.location.start_offset).presence
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

          # Where generated files are written.
          def expand_path(relative_path)
            File.expand_path(relative_path, @output_root)
          end

          # Where the committed files live.
          def source_path(relative_path)
            File.expand_path(relative_path, Migrations.root_path)
          end

          def file_header
            @file_header ||=
              begin
                db_label = Helpers.db_label(@output_config.models_namespace)
                <<~HEADER
                  #{GeneratedFiles::MARKER} #{db_label} schema. To make changes,
                  update the configuration files in "migrations/tooling/config/schema/" and then run
                  `migrations/bin/disco schema generate` to regenerate this file.
                HEADER
              end
          end
        end
      end
    end
  end
end
