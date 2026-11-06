# frozen_string_literal: true

require "compression/safe_zip_reader"

module ::Blog
  # Reads a theme from an archive or a Git repository without saving it.
  class ThemeImporter
    MANIFEST = "blog-theme.json"
    MANIFEST_VERSIONS = [1, 2].freeze
    MAX_MANIFEST_BYTES = 4096
    MAX_ARCHIVE_ENTRIES = 1000

    InvalidTheme = Class.new(StandardError)
    ImportedTheme = Data.define(:attributes, :source)

    class GitSource < ThemeStore::GitImporter
      def import!
        # Blog sources do not use framework compatibility refs or additional fetches.
        clone!
      end

      protected

      def redirected_uri
        uri = super
        raise_import_error! unless uri.scheme == "https"
        uri
      end

      def clone_args(url, config = {})
        super(
          url,
          config.merge(
            "protocol.allow" => "never",
            "protocol.https.allow" => "always",
            "http.sslVerify" => "true",
          ),
        )
      end
    end

    # Reads a checkout through the same interface as Compression::SafeZipReader.
    class Checkout
      def initialize(importer)
        @importer = importer
      end

      def read_entry(name, max_bytes:, required: false)
        path = contained_file(name)
        if !path
          raise InvalidTheme, I18n.t("blog.themes.manifest_invalid") if required
          return
        end
        if File.size(path) > max_bytes
          raise InvalidTheme, I18n.t("blog.themes.file_too_large", file: name)
        end
        File.read(path)
      end

      private

      # Symlinks must not escape the checkout.
      def contained_file(name)
        path = @importer.real_path(name)
        return if !path&.start_with?("#{@importer.temp_folder}/")
        path if File.file?(path)
      end
    end

    # Reads a theme folder shipped with the plugin.
    class Directory
      def initialize(root)
        @root = root
      end

      def read_entry(name, max_bytes:, required: false)
        path = File.join(@root, name)
        if !File.file?(path)
          raise InvalidTheme, I18n.t("blog.themes.manifest_invalid") if required
          return
        end
        if File.size(path) > max_bytes
          raise InvalidTheme, I18n.t("blog.themes.file_too_large", file: name)
        end
        File.read(path)
      end
    end

    def self.read_directory(path)
      read_attributes(Directory.new(path))
    end

    def self.read_archive(path)
      Compression::SafeZipReader.open(path, max_entries: MAX_ARCHIVE_ENTRIES) do |reader|
        ImportedTheme.new(attributes: read_attributes(reader), source: nil)
      end
    rescue Compression::SafeZipReader::Error, Zip::Error, Zlib::Error
      raise InvalidTheme, I18n.t("blog.themes.archive_invalid")
    end

    def self.read_repository(repository, branch:)
      git = GitSource.new(repository, branch:)
      git.import!
      ImportedTheme.new(
        attributes: read_attributes(Checkout.new(git)),
        source: {
          "repository" => repository,
          "branch" => branch,
          "commit" => git.version,
        },
      )
    ensure
      git&.cleanup!
    end

    def self.read_attributes(files)
      manifest = read_manifest(files)
      attributes = manifest.slice("name", *BlogTheme::COLOR_FIELDS)
      attributes["css"] = read(files, "blog.css", BlogTheme::MAX_CODE_BYTES)
      attributes["javascript"] = read(files, "blog.js", BlogTheme::MAX_CODE_BYTES)
      return attributes if manifest["version"] == 1

      TemplateRenderer::PAGES.each do |page|
        attributes["template_#{page}"] = read(
          files,
          "templates/#{page}.liquid",
          TemplateRenderer::MAX_TEMPLATE_BYTES,
        )
      end
      attributes
    end
    private_class_method :read_attributes

    def self.read_manifest(files)
      manifest = JSON.parse(read(files, MANIFEST, MAX_MANIFEST_BYTES, required: true))
      return manifest if manifest.is_a?(Hash) && MANIFEST_VERSIONS.include?(manifest["version"])
      raise InvalidTheme, I18n.t("blog.themes.manifest_invalid")
    rescue JSON::ParserError
      raise InvalidTheme, I18n.t("blog.themes.manifest_invalid")
    end
    private_class_method :read_manifest

    def self.read(files, name, max_bytes, required: false)
      files.read_entry(name, max_bytes:, required:)&.force_encoding(Encoding::UTF_8) || ""
    end
    private_class_method :read
  end
end
