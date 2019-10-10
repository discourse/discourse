# frozen_string_literal: true

require_dependency 'stylesheet/common'
require_dependency 'global_path'

module Stylesheet
  class Importer < SassC::Importer
    include GlobalPath

    THEME_TARGETS ||= %w{embedded_theme mobile_theme desktop_theme}

    def self.special_imports
      @special_imports ||= {}
    end

    def self.register_import(name, &blk)
      special_imports[name] = blk
    end

    # Contained in function so that it can be called repeatedly from test mode
    def self.register_imports!
      @special_imports = {}

      register_import "theme_field" do
        Import.new("#{theme_dir(@theme_id)}/theme_field.scss", source: @theme_field)
      end

      Discourse.plugins.each do |plugin|
        plugin_directory_name = plugin.directory_name

        ["", "mobile", "desktop"].each do |type|
          asset_name = type.present? ? "#{plugin_directory_name}_#{type}" : plugin_directory_name
          stylesheets = type.present? ? DiscoursePluginRegistry.send("#{type}_stylesheets") : DiscoursePluginRegistry.stylesheets

          if stylesheets[plugin_directory_name].present?
            register_import asset_name do
              import_files(stylesheets[plugin_directory_name])
            end
          end
        end
      end

      register_import "plugins_variables" do
        import_files(DiscoursePluginRegistry.sass_variables)
      end

      register_import "theme_colors" do
        contents = +""
        colors = (@theme_id && theme.color_scheme) ? theme.color_scheme.resolved_colors : ColorScheme.base_colors
        colors.each do |n, hex|
          contents << "$#{n}: ##{hex} !default;\n"
        end

        Import.new("theme_colors.scss", source: contents)
      end

      register_import "theme_variables" do
        contents = +""

        theme&.all_theme_variables&.each do |field|
          if field.type_id == ThemeField.types[:theme_upload_var]
            if upload = field.upload
              url = upload_cdn_path(upload.url)
              contents << "$#{field.name}: unquote(\"#{url}\");\n"
            end
          else
            contents << to_scss_variable(field.name, field.value)
          end
        end

        theme&.included_settings&.each do |name, value|
          next if name == "theme_uploads"
          contents << to_scss_variable(name, value)
        end

        Import.new("theme_variable.scss", source: contents)
      end

      register_import "category_backgrounds" do
        contents = +""
        Category.where('uploaded_background_id IS NOT NULL').each do |c|
          contents << category_css(c) if c.uploaded_background&.url.present?
        end

        Import.new("category_background.scss", source: contents)
      end

      register_import "embedded_theme" do
        next unless @theme_id

        theme_import(:common, :embedded_scss)
      end

      register_import "mobile_theme" do
        next unless @theme_id

        theme_import(:mobile, :scss)
      end

      register_import "desktop_theme" do
        next unless @theme_id

        theme_import(:desktop, :scss)
      end
    end

    register_imports!

    def initialize(options)
      @theme = options[:theme]
      @theme_id = options[:theme_id]
      @theme_field = options[:theme_field]
      if @theme && !@theme_id
        # make up an id so other stuff does not bail out
        @theme_id = @theme.id || -1
      end
      @importable_theme_fields = {}
    end

    def import_files(files)
      files.map do |file|
        # we never want inline css imports, they are a mess
        # this tricks libsass so it imports inline instead
        if file =~ /\.css$/
          file = file[0..-5]
        end
        Import.new(file)
      end
    end

    def theme_import(target, attr)
      fields = theme.list_baked_fields(target, attr)

      fields.map do |field|
        value = field.value
        if value.present?
          filename = "theme_#{field.theme.id}/#{field.target_name}-#{field.name}-#{field.theme.name.parameterize}.scss"
          with_comment = <<~COMMENT
          // Theme: #{field.theme.name}
          // Target: #{field.target_name} #{field.name}
          // Last Edited: #{field.updated_at}

          #{value}
          COMMENT
          Import.new(filename, source: with_comment)
        end
      end.compact
    end

    def theme
      unless @theme
        @theme = (@theme_id && Theme.find(@theme_id)) || :nil
      end
      @theme == :nil ? nil : @theme
    end

    def theme_dir(import_theme_id)
      "theme_#{import_theme_id}"
    end

    def extract_theme_id(path)
      path[/^theme_([0-9]+)\//, 1]
    end

    def importable_theme_fields(import_theme_id)
      return {} unless theme && import_theme = Theme.find(import_theme_id)
      @importable_theme_fields[import_theme_id] ||= begin
        hash = {}
        import_theme.theme_fields.where(target_id: Theme.targets[:extra_scss]).each do |field|
          hash[field.name] = field.value
        end
        hash
      end
    end

    def match_theme_import(path, parent_path)
      # Only allow importing theme stylesheets from within stylesheets in the same theme
      return false unless theme && import_theme_id = extract_theme_id(parent_path) # Could be a child theme
      parent_dir, _ = File.split(parent_path)

      # Could be relative to the importing file, or relative to the root of the theme directory
      search_paths = [parent_dir, theme_dir(import_theme_id)].uniq
      search_paths.each do |search_path|
        resolved = Pathname.new("#{search_path}/#{path}").cleanpath.to_s # Remove unnecessary ./ and ../
        next unless resolved.start_with?("#{theme_dir(import_theme_id)}/")
        resolved_within_theme = resolved.sub(/^theme_[0-9]+\//, "")
        if importable_theme_fields(import_theme_id).keys.include?(resolved_within_theme)
          return resolved, importable_theme_fields(import_theme_id)[resolved_within_theme]
        end
      end
      false
    end

    def category_css(category)
      "body.category-#{category.full_slug} { background-image: url(#{upload_cdn_path(category.uploaded_background.url)}) }\n"
    end

    def to_scss_variable(name, value)
      escaped = SassC::Script::Value::String.quote(value, sass: true)
      "$#{name}: unquote(#{escaped});\n"
    end

    def imports(asset, parent_path)
      if asset[-1] == "*"
        Dir["#{Stylesheet::Common::ASSET_ROOT}/#{asset}.scss"].map do |path|
          Import.new(asset[0..-2] + File.basename(path, ".*"))
        end
      elsif callback = Importer.special_imports[asset]
        instance_eval(&callback)
      elsif (path, source = match_theme_import(asset, parent_path))
        Import.new(path, source: source)
      else
        Import.new(asset + ".scss")
      end
    end
  end
end
