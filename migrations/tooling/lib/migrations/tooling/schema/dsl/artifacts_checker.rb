# frozen_string_literal: true

require "tmpdir"

module Migrations
  module Tooling
    module Schema
      module DSL
        # Compares the committed generated artifacts (SQL schema, models and
        # enums) with what `disco schema generate` would produce right now.
        # Generation happens in a temporary directory, so the working tree
        # stays untouched.
        class ArtifactsChecker
          Result =
            Data.define(:changed, :missing, :stale) do
              def clean?
                changed.empty? && missing.empty? && stale.empty?
              end
            end

          def initialize(schema_module, database: :intermediate_db)
            @schema = schema_module
            @database = database
            @output_config = schema_module.config.output_config
          end

          def check
            Dir.mktmpdir("disco-schema-check-") do |tmp_root|
              resolved = @schema.generate(database: @database, output_root: tmp_root).resolved
              compare(resolved, tmp_root)
            end
          end

          private

          def compare(resolved, tmp_root)
            changed = []
            missing = []

            # The same file list rooted at the two locations and in the same
            # order, so each committed file lines up with its freshly generated
            # counterpart.
            committed = expected_paths(resolved, Migrations.root_path)
            generated = expected_paths(resolved, tmp_root)

            committed
              .zip(generated)
              .each do |committed_path, generated_path|
                relative = relative_path(committed_path)

                if !File.exist?(committed_path)
                  missing << relative
                elsif File.read(committed_path) != File.read(generated_path)
                  changed << relative
                end
              end

            Result.new(changed:, missing:, stale: stale_files(resolved))
          end

          # The files generation produces, rooted at `root`: the SQL schema plus
          # one file per generated model and enum.
          def expected_paths(resolved, root)
            [File.expand_path(@output_config.schema_file, root)] +
              GeneratedFiles.expected_paths(resolved, @output_config, root)
          end

          # Committed generated files that generation no longer produces,
          # e.g. the model of a table that was removed from the config.
          def stale_files(resolved)
            root = Migrations.root_path
            expected = GeneratedFiles.expected_paths(resolved, @output_config, root)

            GeneratedFiles
              .stale_paths(@output_config, root, expected)
              .map { |path| relative_path(path) }
              .sort
          end

          def relative_path(path)
            Pathname.new(path).relative_path_from(Migrations.root_path).to_s
          end
        end
      end
    end
  end
end
