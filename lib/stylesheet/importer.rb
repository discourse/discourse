require_dependency 'stylesheet/common'

module Stylesheet
  class Importer < SassC::Importer

    @special_imports = {}

    def self.special_imports
      @special_imports
    end

    def self.register_import(name, &blk)
      @special_imports[name] = blk
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
      Import.new("theme_variable.scss", source: contents)
    end

    register_import "category_backgrounds" do
      contents = ""
      Category.where('uploaded_background_id IS NOT NULL').each do |c|
        contents << category_css(c) if c.uploaded_background
      end

      Import.new("categoy_background.scss", source: contents)
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
      @theme_id = options[:theme_id]
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
      @theme ||= Theme.find(@theme_id)
    end

    def apply_cdn(url)
      "#{GlobalSetting.cdn_url}#{url}"
    end

    def category_css(category)
      "body.category-#{category.full_slug} { background-image: url(#{apply_cdn(category.uploaded_background.url)}) }\n"
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
