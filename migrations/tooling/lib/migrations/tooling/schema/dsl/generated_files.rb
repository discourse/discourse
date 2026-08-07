# frozen_string_literal: true

module Migrations
  module Tooling
    module Schema
      module DSL
        # Single source of truth for the set of files `disco schema generate`
        # produces. Both the generator (which deletes files it no longer
        # produces) and the artifacts checker (which detects drift between the
        # committed files and a fresh generation) ask this module which files are
        # expected and which committed files are now stale, so the two can't
        # disagree about what "a generated file" is.
        module GeneratedFiles
          # The marker the generator writes into the header of every generated
          # file (see Generator#file_header). Hand-written ("manual") models lack
          # it, which is how generated files are told apart from them.
          MARKER = "This file is auto-generated from the"

          # Absolute paths of the model and enum files generation produces for
          # `resolved`, rooted at `root`. Manual models are hand-written, so they
          # are excluded. The SQL schema file is not included — callers that need
          # it add it themselves.
          def self.expected_paths(resolved, output_config, root)
            models_dir = File.expand_path(output_config.models_directory, root)
            enums_dir = File.expand_path(output_config.enums_directory, root)

            model_paths =
              resolved
                .tables
                .reject { |table| table.model_mode == :manual }
                .map { |table| File.join(models_dir, ModelWriter.filename_for(table)) }

            enum_paths =
              resolved.enums.map { |enum| File.join(enums_dir, EnumWriter.filename_for(enum)) }

            model_paths + enum_paths
          end

          # Absolute paths of generated `*.rb` files under `root`'s model and enum
          # directories that the current definition no longer produces: they carry
          # the auto-generated {MARKER} but are not in `expected` (the result of
          # {expected_paths} for the same `root`). Hand-written models lack the
          # marker and are never returned.
          def self.stale_paths(output_config, root, expected)
            expected = expected.to_set

            [output_config.models_directory, output_config.enums_directory].uniq.flat_map do |dir|
              Dir[File.join(File.expand_path(dir, root), "*.rb")].select do |path|
                !expected.include?(path) && File.read(path).include?(MARKER)
              end
            end
          end
        end
      end
    end
  end
end
