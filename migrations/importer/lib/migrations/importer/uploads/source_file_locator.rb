# frozen_string_literal: true

require "tempfile"

module Migrations
  module Importer
    module Uploads
      # Finds the file behind an `upload_sources` row that carries its bytes
      # locally: either inline in a `data` blob, or on disk under one of the
      # configured `root_paths`. URL-backed rows go through {Downloader}
      # instead. No Rails, no DB — just paths and tempfiles, so it unit-tests on
      # its own.
      class SourceFileLocator
        def initialize(root_paths:, path_replacements: [])
          @root_paths = root_paths || []
          @path_replacements = path_replacements
        end

        # Writes the row's inline `data` blob to a tempfile and returns it. The
        # caller owns the tempfile and must close it (`close!`).
        def tempfile_from_data(data)
          file = Tempfile.new("discourse-upload", binmode: true)
          file.write(data)
          file.rewind
          file
        end

        # Looks for the row's `path` under each root, first as recorded and then
        # with each path replacement applied. A row without a `path` is looked up
        # by its `filename` directly under each root. Returns the first existing
        # file, or nil.
        def find_file_in_paths(row)
          candidates = candidate_paths(row)

          @root_paths.each do |root_path|
            root = real_root(root_path)
            next if root.nil?

            candidates.each do |candidate|
              path = contained_file(root, candidate)
              return path if path
            end
          end

          nil
        end

        private

        def candidate_paths(row)
          path = row[:path]
          return [File.basename(row[:filename].to_s)] if path.blank?

          [path, *@path_replacements.map { |from, to| path.sub(from, to) }].uniq
        end

        def real_root(root_path)
          @real_roots ||= {}
          @real_roots.fetch(root_path) do
            @real_roots[root_path] = (
              begin
                File.realpath(root_path)
              rescue StandardError
                nil
              end
            )
          end
        end

        # The IntermediateDB may come from a third party, so a recorded path is
        # untrusted: resolved (symlinks included) it has to stay inside the root,
        # or the import would turn any readable file on the box into an upload.
        def contained_file(root, candidate)
          path = File.realpath(File.join(root, candidate))
          return nil unless path.start_with?("#{root}/") && File.file?(path)

          path
        rescue SystemCallError
          nil
        end
      end
    end
  end
end
