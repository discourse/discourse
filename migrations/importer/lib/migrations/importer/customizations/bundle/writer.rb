# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "tmpdir"
require "zip"

module Migrations
  module Importer
    module Customizations
      module Bundle
        class Writer
          SAFE_EXTENSION = /\A\.[a-z0-9]{1,10}\z/i

          def self.open
            Dir.mktmpdir("customizations-export") { |dir| yield new(dir) }
          end

          def initialize(staging_dir)
            @staging_dir = staging_dir
            @uploads = {}
            @theme_dirs = Set.new
          end

          # Stores a file under its content hash, so equal files are kept once.
          # @return [String] the path inside the bundle
          def add_upload(source_path, original_filename)
            sha1 = Digest::SHA1.file(source_path).hexdigest
            extension = File.extname(original_filename.to_s).downcase
            extension = "" unless SAFE_EXTENSION.match?(extension)
            path = "#{UPLOADS_DIR}/#{sha1}#{extension}"

            @uploads[path] ||= begin
              copy(source_path, path)
              path
            end
          end

          # @return [String] the path inside the bundle
          def add_theme_directory(source_dir, name)
            base = name.to_s.downcase.gsub(/[^0-9a-z]+/, "-").delete_prefix("-").delete_suffix("-")
            base = "theme" if base.empty?
            dir = base
            suffix = 1
            dir = "#{base}-#{suffix += 1}" while @theme_dirs.include?(dir)
            @theme_dirs << dir

            path = "#{THEMES_DIR}/#{dir}"
            destination = File.join(@staging_dir, path)
            FileUtils.mkdir_p(File.dirname(destination))
            FileUtils.cp_r(source_dir, destination)
            path
          end

          def write(output_path, manifest)
            File.write(File.join(@staging_dir, MANIFEST), JSON.pretty_generate(manifest))

            FileUtils.rm_f(output_path)
            Zip::File.open(output_path, create: true) do |zip|
              Dir
                .glob("**/*", base: @staging_dir)
                .sort
                .each do |relative|
                  source = File.join(@staging_dir, relative)
                  zip.add(relative, source) if File.file?(source)
                end
            end
          end

          private

          def copy(source_path, path)
            destination = File.join(@staging_dir, path)
            FileUtils.mkdir_p(File.dirname(destination))
            FileUtils.cp(source_path, destination)
          end
        end
      end
    end
  end
end
