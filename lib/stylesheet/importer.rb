require_dependency 'stylesheet/common'
require_dependency 'global_path'

module Stylesheet
  class Importer < SassC::Importer
    include GlobalPath

    def self.special_imports
      @special_imports ||= {}
    end

    def self.register_import(name, &blk)
      special_imports[name] = blk
    end

    register_import "theme_field" do
      Import.new("theme_field.scss", source: @theme_field)
    end

    register_import "plugins" do
      import_files(DiscoursePluginRegistry.stylesheets)
    end

    register_import "plugins_mobile" do
      import_files(DiscoursePluginRegistry.mobile_stylesheets)
    end

    register_import "plugins_desktop" do
      import_files(DiscoursePluginRegistry.desktop_stylesheets)
    end

    register_import "plugins_variables" do
      import_files(DiscoursePluginRegistry.sass_variables)
    end

    register_import "theme_variables" do
      contents = ""
      colors = (@theme_id && theme.color_scheme) ? theme.color_scheme.resolved_colors : ColorScheme.base_colors
      colors.each do |n, hex|
        contents << "$#{n}: ##{hex} !default;\n"
      end

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
        contents << to_scss_variable(name, value)
      end

      Import.new("theme_variable.scss", source: contents)
    end

    register_import "category_backgrounds" do
      contents = ""
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

    def initialize(options)
      @theme = options[:theme]
      @theme_id = options[:theme_id]
      @theme_field = options[:theme_field]
      if @theme && !@theme_id
        # make up an id so other stuff does not bail out
        @theme_id = @theme.id || -1
      end
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
          filename = "#{field.theme.id}/#{field.target_name}-#{field.name}-#{field.theme.name.parameterize}.scss"
          with_comment = <<COMMENT
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

    def category_css(category)
      "body.category-#{category.full_slug} { background-image: url(#{upload_cdn_path(category.uploaded_background.url)}) }\n"
    end

    def to_scss_variable(name, value)
      escaped = value.to_s.gsub('"', "\\22")
      escaped.gsub!("\n", "\\A")
      "$#{name}: unquote(\"#{escaped}\");\n"
    end

    def imports(asset, parent_path)
      if asset[-1] == "*"
        Dir["#{Stylesheet::ASSET_ROOT}/#{asset}.scss"].map do |path|
          Import.new(asset[0..-2] + File.basename(path, ".*"))
        end
      elsif callback = Importer.special_imports[asset]
        instance_eval(&callback)
      else
        Import.new(asset + ".scss")
      end
    end
  end
end
