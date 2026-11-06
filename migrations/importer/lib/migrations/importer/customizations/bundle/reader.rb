# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"
require "zip"

module Migrations
  module Importer
    module Customizations
      module Bundle
        # Extracts a bundle after checking every entry, and resolves paths the
        # manifest refers to. The manifest is untrusted input.
        class Reader
          MAX_ENTRIES = 20_000
          MAX_TOTAL_SIZE = 2 * 1024 * 1024 * 1024

          attr_reader :manifest

          def self.open(zip_path)
            raise Error, "Bundle not found: #{zip_path}" unless File.file?(zip_path)

            Dir.mktmpdir("customizations-apply") do |dir|
              reader = new(zip_path, File.realpath(dir))
              reader.extract!
              yield reader
            end
          end

          def initialize(zip_path, extract_dir)
            @zip_path = zip_path
            @extract_dir = extract_dir
          end

          def extract!
            Zip::File.open(@zip_path) do |zip|
              entries = zip.entries
              raise Error, "Bundle has too many entries" if entries.size > MAX_ENTRIES
              if entries.sum { |entry| entry.size.to_i } > MAX_TOTAL_SIZE
                raise Error, "Bundle is too large"
              end

              entries.each { |entry| extract_entry(entry) }
            end

            @manifest = load_manifest
          rescue Zip::Error => e
            raise Error, "Bundle is not a valid ZIP file: #{e.message}"
          end

          # @return [String] absolute path of a file inside the bundle
          def file_path(relative, prefix:)
            path = resolve(relative, prefix)
            raise Error, "Missing file in bundle: #{relative}" unless File.file?(path)
            path
          end

          # @return [String] absolute path of a directory inside the bundle
          def directory_path(relative, prefix:)
            path = resolve(relative, prefix)
            raise Error, "Missing directory in bundle: #{relative}" unless File.directory?(path)
            path
          end

          private

          def extract_entry(entry)
            name = entry.name
            check_name!(name)

            if entry.symlink?
              raise Error, "Bundle entry '#{name}' is a symlink"
            elsif !entry.directory? && !entry.file?
              raise Error, "Bundle entry '#{name}' is not a regular file"
            end

            destination = File.expand_path(name, @extract_dir)
            unless destination.start_with?(File.join(@extract_dir, ""))
              raise Error, "Bundle entry '#{name}' would be extracted outside the bundle"
            end

            if entry.directory?
              FileUtils.mkdir_p(destination)
            else
              FileUtils.mkdir_p(File.dirname(destination))
              File.open(destination, "wb") do |file|
                entry.get_input_stream { |stream| IO.copy_stream(stream, file) }
              end
            end
          end

          def check_name!(name)
            if name.empty? || name.start_with?("/", "\\") || name.match?(/\A[a-zA-Z]:/)
              raise Error, "Bundle entry '#{name}' has an absolute path"
            end
            if name.split(%r{[/\\]}).include?("..")
              raise Error, "Bundle entry '#{name}' contains '..'"
            end
            raise Error, "Bundle entry '#{name}' contains a NUL byte" if name.include?("\0")
          end

          def load_manifest
            path = File.join(@extract_dir, MANIFEST)
            raise Error, "Bundle has no #{MANIFEST}" unless File.file?(path)

            manifest = JSON.parse(File.read(path))
            raise Error, "#{MANIFEST} must be a JSON object" unless manifest.is_a?(Hash)
            if manifest["format_version"] != FORMAT_VERSION
              raise Error,
                    "Unsupported bundle format_version: #{manifest["format_version"].inspect}"
            end
            manifest
          rescue JSON::ParserError => e
            raise Error, "#{MANIFEST} is not valid JSON: #{e.message}"
          end

          def resolve(relative, prefix)
            unless relative.is_a?(String) && relative.start_with?("#{prefix}/")
              raise Error, "Invalid bundle path: #{relative.inspect}"
            end
            check_name!(relative)

            path = File.expand_path(relative, @extract_dir)
            unless path.start_with?(File.join(@extract_dir, prefix, ""))
              raise Error, "Invalid bundle path: #{relative.inspect}"
            end
            path
          end
        end
      end
    end
  end
end
