# frozen_string_literal: true

require "tempfile"

module Migrations
  module Importer
    module Uploads
      # Finds the file behind an `upload_sources` row that carries its bytes
      # locally: either inline in a `data` blob, or on disk under one of the
      # configured `root_paths`. URL-backed rows go through {FileDownloader}
      # instead. No Rails, no DB — just paths and tempfiles, so it unit-tests on
      # its own.
      class SourceFileLocator
        def initialize(root_paths:, path_replacements: [])
          @root_paths = root_paths
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

        # Resolves the row against the configured roots, trying each root first
        # verbatim and then with every path replacement applied. Returns the first
        # path that exists, or nil.
        def find_file_in_paths(row)
          relative_path = row[:relative_path] || ""

          @root_paths.each do |root_path|
            path = File.join(root_path, relative_path, row[:filename])
            return path if File.exist?(path)

            @path_replacements.each do |from, to|
              path = File.join(root_path, relative_path.sub(from, to), row[:filename])
              return path if File.exist?(path)
            end
          end

          nil
        end
      end
    end
  end
end
