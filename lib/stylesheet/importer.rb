# frozen_string_literal: true

require "global_path"

module Stylesheet
  class Importer
    include GlobalPath

    THEME_TARGETS = %w[embedded_theme common_theme mobile_theme desktop_theme]

    def self.plugin_assets
      @plugin_assets ||= {}
    end

    def self.register_imports!
      Discourse.plugins.each do |plugin|
        plugin_directory_name = plugin.directory_name

        ["", "mobile", "desktop"].each do |type|
          asset_name = type.present? ? "#{plugin_directory_name}_#{type}" : plugin_directory_name
          stylesheets =
            (
              if type.present?
                DiscoursePluginRegistry.send("#{type}_stylesheets")
              else
                DiscoursePluginRegistry.stylesheets
              end
            )

          if plugin_directory_name.present?
            plugin_assets[asset_name] = {
              plugin_path: plugin.path,
              stylesheets: stylesheets[plugin_directory_name],
            }
          end
        end
      end
    end

    register_imports!

    def font
      body_font = DiscourseFonts.fonts.find { |f| f[:key] == SiteSetting.base_font }
      heading_font = DiscourseFonts.fonts.find { |f| f[:key] == SiteSetting.heading_font }
      contents = +""

      contents << <<~CSS if body_font.present?
          // Body font definition
          #{font_css(body_font)}
          #{render_font_special_properties(body_font, "body")}
          :root {
            --font-family: #{body_font[:stack]};
          }

        CSS

      contents << <<~CSS if heading_font.present?
          // Heading font definition
          #{font_css(heading_font)}
          #{render_font_special_properties(heading_font, "heading")}
          :root {
            --heading-font-family: #{heading_font[:stack]};
          }

        CSS

      if SiteSetting.rich_editor
        contents << <<~CSS
          #{font_css(jetbrains_mono)}
          #{render_font_special_properties(jetbrains_mono, "body")}
          :root {
            --d-font-family--monospace: #{jetbrains_mono[:stack]};
          }

        CSS
      else
        contents << <<~CSS
          :root {
            --d-font-family--monospace: ui-monospace, "Cascadia Mono", "Segoe UI Mono", "Liberation Mono", menlo, monaco, consolas, monospace;
          }

        CSS
      end

      contents
    end

    def jetbrains_mono
      @@jetbrains_mono ||= DiscourseFonts.fonts.find { |f| f[:key] == "jet_brains_mono" }
    end

    def wizard_fonts
      contents = +""

      DiscourseFonts.fonts.each do |font|
        if font[:key] == "system"
          # Overwrite font definition because the preview canvases in the wizard require explicit @font-face definitions.
          # uses same technique as https://github.com/jonathantneal/system-font-css
          font[:variants] = [
            {
              src:
                'local(".SFNS-Regular"), local(".SFNSText-Regular"), local(".HelveticaNeueDeskInterface-Regular"), local(".LucidaGrandeUI"), local("Segoe UI"), local("Ubuntu"), local("Roboto-Regular"), local("DroidSans"), local("Tahoma")',
              weight: 400,
            },
            {
              src:
                'local(".SFNS-Bold"), local(".SFNSText-Bold"), local(".HelveticaNeueDeskInterface-Bold"), local(".LucidaGrandeUI"), local("Segoe UI Bold"), local("Ubuntu Bold"), local("Roboto-Bold"), local("DroidSans-Bold"), local("Tahoma Bold")',
              weight: 700,
            },
          ]
        end

        contents << font_css(font)
        contents << <<~CSS
          .body-font-#{font[:key].tr("_", "-")} {
            font-family: #{font[:stack]};
          }
          .heading-font-#{font[:key].tr("_", "-")} {
            font-family: #{font[:stack]};
          }
        CSS
        contents << render_wizard_font_special_properties(font)
      end

      contents
    end

    def import_color_definitions
      contents = +""
      DiscoursePluginRegistry.color_definition_stylesheets.each do |name, path|
        contents << "\n\n// Color definitions from #{name}\n\n"
        contents << File.read(path.to_s)
        contents << "\n\n"
      end

      theme_id = @theme_id || SiteSetting.default_theme_id
      resolved_ids = Theme.transform_ids(theme_id)

      if resolved_ids
        Theme
          .list_baked_fields(resolved_ids, :common, :color_definitions)
          .each do |field|
            contents << "\n\n// Color definitions from #{field.theme.name}\n\n"
            contents << field.compiled_css(prepended_scss)
            contents << "\n\n"
          end
      end
      contents
    end

    def import_wcag_overrides
      if @color_scheme_id && ColorScheme.find_by_id(@color_scheme_id)&.is_wcag?
        return "@import \"wcag\";"
      end
      ""
    end

    def color_variables
      contents = +""
      if @color_scheme_id
        colors =
          begin
            ColorScheme.find(@color_scheme_id).resolved_colors(dark: @dark)
          rescue StandardError
            ColorScheme.base_colors
          end
      elsif (@theme_id && !theme.component)
        colors = theme&.color_scheme&.resolved_colors(dark: @dark) || ColorScheme.base_colors
      else
        # this is a slightly ugly backwards compatibility fix,
        # we shouldn't be using the default theme color scheme for components
        # (most components use CSS custom properties which work fine without this)
        colors =
          Theme
            .find_by_id(SiteSetting.default_theme_id)
            &.color_scheme
            &.resolved_colors(dark: @dark) || ColorScheme.base_colors
      end

      colors.each { |n, hex| contents << "$#{n}: ##{hex} !default; " }

      contents
    end

    def public_image_path
      image_path = UrlHelper.absolute("#{Discourse.base_path}/images")
      "$public_image_path: \"#{image_path}\"; "
    end

    def prepended_scss
      "#{color_variables} #{public_image_path} @import \"common/foundation/variables\"; @import \"common/foundation/mixins\"; "
    end

    def initialize(options)
      @theme = options[:theme]
      @theme_id = options[:theme_id]
      @color_scheme_id = options[:color_scheme_id]
      @dark = options[:dark]

      if @theme && !@theme_id
        # make up an id so other stuff does not bail out
        @theme_id = @theme.id || -1
      end
    end

    def theme_import(target)
      return "" if !@theme_id

      name = :scss

      if target == :embedded_theme
        name = :embedded_scss
        target = :common
      end

      target = target.to_s.gsub("_theme", "").to_sym

      contents = +""

      fields = theme.list_baked_fields(target, name)
      fields.map do |field|
        contents << "@import \"theme-entrypoint/#{field.scss_entrypoint_name}\";\n"
      end
      contents
    end

    def theme
      @theme = (@theme_id && Theme.find(@theme_id)) || :nil unless @theme
      @theme == :nil ? nil : @theme
    end

    def font_css(font)
      contents = +""

      if font[:variants].present?
        fonts_dir = UrlHelper.absolute("#{Discourse.base_path}/fonts")
        font[:variants].each do |variant|
          src =
            (
              if variant[:src]
                variant[:src]
              else
                "url(\"#{fonts_dir}/#{variant[:filename]}?v=#{DiscourseFonts::VERSION}\") format(\"#{variant[:format]}\")"
              end
            )

          contents << <<~CSS
            @font-face {
              font-family: '#{font[:name]}';
              src: #{src};
              font-weight: #{variant[:weight]};
            }
          CSS
        end
      end

      contents
    end

    def render_font_special_properties(font, font_type)
      contents = +""
      root_elements = font_type == "body" ? "html" : "h1, h2, h3, h4, h5, h6"
      contents << "#{root_elements} {\n"
      contents << font_special_properties(font)
      contents << "}\n"
    end

    def render_wizard_font_special_properties(font)
      contents = +""
      contents << ".wizard-container-heading-font-#{font[:key]} {\n"
      contents << "  h1, h2, h3, h4, h5, h6 {\n"
      contents << font_special_properties(font, 4)
      contents << "  }\n"
      contents << "}\n"
      contents << ".wizard-container-body-font-#{font[:key]} {\n"
      contents << font_special_properties(font)
      contents << "}\n"
    end

    def font_special_properties(font, indent = 2)
      contents = +""
      if font[:font_variation_settings].present?
        contents << "#{" " * indent}font-variation-settings: #{font[:font_variation_settings]};\n"
      else
        contents << "#{" " * indent}font-variation-settings: normal;\n"
      end

      if font[:font_feature_settings].present?
        contents << "#{" " * indent}font-feature-settings: #{font[:font_feature_settings]};\n"
      else
        contents << "#{" " * indent}font-feature-settings: normal;\n"
      end

      # avoiding adding normal to the CSS cause it is not needed in this case
      if font[:font_variant_ligatures].present?
        contents << "#{" " * indent}font-variant-ligatures: #{font[:font_variant_ligatures]};\n"
      end

      contents
    end
  end
end
