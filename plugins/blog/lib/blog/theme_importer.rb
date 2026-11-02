# frozen_string_literal: true

require "compression/safe_zip_reader"

module ::Blog
  class ThemeImporter
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

    def self.import(repository:, branch:, user:, id: nil, revision: nil)
      if !repository.is_a?(String) || (!branch.nil? && !branch.is_a?(String))
        raise Discourse::InvalidParameters.new(:repository)
      end
      uri = URI.parse(repository)
      unless repository.length <= 1000 && uri.is_a?(URI::HTTPS) && uri.host.present? &&
               !uri.userinfo && !uri.query && !uri.fragment
        raise Discourse::InvalidParameters.new(I18n.t("blog.themes.repository_invalid"))
      end
      branch = branch.presence
      if branch && (branch.length > 200 || branch.start_with?("-") || branch.match?(/[\x00-\x20]/))
        raise Discourse::InvalidParameters.new(:branch)
      end
      user.guardian.ensure_allowed_theme_repo_import!(repository)
      importer = GitSource.new(repository, branch: branch)
      begin
        importer.import!
        values =
          read_values do |name, limit, required: false|
            read_file(importer, name, limit, required: required)
          end
        BlogTheme.save(
          values,
          user: user,
          id: id,
          revision: revision,
          source: {
            "repository" => repository,
            "branch" => branch,
            "commit" => importer.version,
          },
        )
      ensure
        importer.cleanup!
      end
    rescue JSON::ParserError, URI::InvalidURIError
      raise Discourse::InvalidParameters.new(I18n.t("blog.themes.manifest_invalid"))
    end

    def self.import_file(file:, user:)
      unless file.is_a?(ActionDispatch::Http::UploadedFile) &&
               File.extname(file.original_filename).downcase == ".zip" && file.size <= 2.megabytes
        raise Discourse::InvalidParameters.new(:file)
      end

      Compression::SafeZipReader.open(file.path, max_entries: 1000) do |reader|
        values =
          read_values do |name, limit, required: false|
            reader.read_entry(name, max_bytes: limit, required: required)&.force_encoding(
              Encoding::UTF_8,
            ) || ""
          end
        BlogTheme.save(values, user: user)
      end
    rescue Compression::SafeZipReader::Error, Zip::Error, Zlib::Error
      raise Discourse::InvalidParameters.new(I18n.t("blog.themes.archive_invalid"))
    end

    def self.read_values
      manifest = JSON.parse(yield("blog-theme.json", 4096, required: true))
      unless manifest.is_a?(Hash) && [1, 2].include?(manifest["version"])
        raise Discourse::InvalidParameters.new(I18n.t("blog.themes.manifest_invalid"))
      end
      values = manifest.slice("name", "accent_color", "paper_color", "ink_color")
      values["css"] = yield("blog.css", BlogTheme::MAX_CODE_BYTES)
      values["javascript"] = yield("blog.js", BlogTheme::MAX_CODE_BYTES)
      if manifest["version"] == 2
        TemplateRenderer::PAGES.each do |page|
          values["template_#{page}"] = yield(
            "templates/#{page}.liquid",
            TemplateRenderer::MAX_TEMPLATE_BYTES
          )
        end
      end
      values
    rescue JSON::ParserError
      raise Discourse::InvalidParameters.new(I18n.t("blog.themes.manifest_invalid"))
    end
    private_class_method :read_values

    def self.read_file(importer, name, limit, required: false)
      path = importer.real_path(name)
      unless path && path.start_with?("#{importer.temp_folder}/") && File.file?(path)
        return "" unless required
        raise Discourse::InvalidParameters.new(I18n.t("blog.themes.manifest_invalid"))
      end
      if importer.file_size(name) > limit
        raise Discourse::InvalidParameters.new(I18n.t("blog.themes.file_too_large", file: name))
      end
      importer[name]
    end
    private_class_method :read_file
  end
end
