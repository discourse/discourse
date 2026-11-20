# frozen_string_literal: true

module ::Blog
  # Read-only designs that ship with the plugin: the built-in look and each
  # theme folder under branding/. Activating one stores only its id, so readers
  # follow plugin updates rather than a frozen copy.
  class ThemePresets
    ROOT = File.expand_path("../../branding", __dir__)
    # Captured by script/capture-theme-screenshots.mjs and served from the
    # plugin's public folder.
    SCREENSHOT_ROOT = File.expand_path("../../public/images/themes", __dir__)
    DEFAULT_ID = "default"
    # Presets cannot be edited, so their revision never advances.
    REVISION = 1

    # Descriptions are looked up per call so they follow the request locale.
    def self.all
      [default, *bundled].map do |preset|
        preset.merge(
          { "description" => I18n.t("blog.themes.descriptions.#{preset["id"]}", default: nil) },
          screenshot_urls.fetch(preset["id"], {}),
        )
      end
    end

    def self.find(id)
      all.find { |preset| preset["id"] == id }
    end

    def self.default
      preset(DEFAULT_ID, BlogTheme.defaults)
    end

    # Reader pages resolve the active theme on every request, so a folder that
    # could not be saved as a draft is skipped rather than raised.
    def self.read_folders(root)
      Dir
        .glob(File.join(root, "*", ThemeImporter::MANIFEST))
        .sort
        .filter_map { |manifest| read_folder(File.dirname(manifest)) }
    end

    def self.bundled
      @bundled ||= read_folders(ROOT).freeze
    end
    private_class_method :bundled

    def self.screenshot_urls
      @screenshot_urls ||=
        Dir
          .glob(File.join(SCREENSHOT_ROOT, "*", "{light,dark}.jpg"))
          .each_with_object({}) do |path, urls|
            id = File.basename(File.dirname(path))
            mode = File.basename(path, ".jpg")
            version = Digest::SHA1.file(path).hexdigest.first(8)
            (urls[id] ||= {})[
              "screenshot_#{mode}_url"
            ] = "#{Discourse.base_path}/plugins/blog/images/themes/#{id}/#{mode}.jpg?v=#{version}"
          end
          .freeze
    end
    private_class_method :screenshot_urls

    def self.read_folder(folder)
      id = File.basename(folder)
      return skip(folder, "#{DEFAULT_ID} is reserved for the built-in design") if id == DEFAULT_ID

      # The manifest must name the theme and its palette, as a Git import must.
      values =
        BlogTheme
          .defaults
          .except("name", *BlogTheme::COLOR_FIELDS)
          .merge(ThemeImporter.read_directory(folder))
      contract = BlogTheme::Create::Contract.new(**values)
      return skip(folder, contract.errors.full_messages.to_sentence) if contract.invalid?

      preset(id, values).freeze
    rescue ThemeImporter::InvalidTheme, SystemCallError => error
      skip(folder, error.message)
    end
    private_class_method :read_folder

    def self.skip(folder, reason)
      Rails.logger.warn("Skipped blog theme #{folder}: #{reason}")
      nil
    end
    private_class_method :skip

    def self.preset(id, values)
      values.merge("id" => id, "revision" => REVISION, "preset" => true)
    end
    private_class_method :preset
  end
end
