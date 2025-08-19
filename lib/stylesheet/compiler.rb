# frozen_string_literal: true

require "stylesheet/importer"

module Stylesheet
  class Compiler
    ASSET_ROOT = "#{Rails.root}/app/assets/stylesheets" unless defined?(ASSET_ROOT)

    def self.compile_asset(asset, options = {})
      importer = Importer.new(options)
      file = importer.prepended_scss
      filename = "_#{asset}_entrypoint.scss"

      if Importer::THEME_TARGETS.include?(asset.to_s)
        filename = "theme_#{options[:theme_id]}.scss"
        file += options[:theme_variables].to_s
        file += importer.theme_import(asset)
      elsif plugin_asset_info = Importer.plugin_assets[asset.to_s]
        options[:load_paths] = [] if options[:load_paths].nil?

        plugin_assets = plugin_asset_info[:stylesheets]
        plugin_path = plugin_asset_info[:plugin_path]
        options[:load_paths] << plugin_path

        plugin_assets.each do |src|
          options[:load_paths] << File.expand_path(File.dirname(src))
          if src.end_with?(".scss")
            file += "@import \"#{src}\";\n"
          else
            file += File.read(src)
          end
        end
      else # Core asset
        file += "@import \"#{asset}\";\n"

        case asset.to_s
        when "embed", "publish"
          file += importer.font
        when "wizard"
          file += importer.wizard_fonts
        when Stylesheet::Manager::COLOR_SCHEME_STYLESHEET
          file += importer.import_color_definitions
          file += importer.import_wcag_overrides
          file += importer.font
        end
      end

      compile(file, filename, options)
    end

    def self.compile(stylesheet, filename, options = {})
      source_map_file = options[:source_map_file] || "#{filename.sub(".scss", "")}.css.map"

      load_paths = [ASSET_ROOT]
      load_paths += options[:load_paths] if options[:load_paths]

      silence_deprecations = %w[color-functions import global-builtin]
      fatal_deprecations = []

      if options[:strict_deprecations]
        fatal_deprecations << "mixed-decls"
      else
        silence_deprecations << "mixed-decls"
      end

      engine =
        SassC::Engine.new(
          stylesheet,
          filename: filename,
          style: :compressed,
          source_map_file: source_map_file,
          source_map_contents: true,
          load_paths: load_paths,
          silence_deprecations:,
          fatal_deprecations:,
          quiet: ENV["QUIET_SASS_DEPRECATIONS"] == "1",
        )

      result = engine.render

      source_map = engine.source_map
      source_map.force_encoding("UTF-8")

      result, source_map =
        DiscourseJsProcessor::Transpiler.new.post_css(
          css: result,
          map: source_map,
          source_map_file: source_map_file,
        )

      if options[:rtl]
        require "rtlcss"
        [Rtlcss.flip_css(result), nil]
      else
        [result, source_map]
      end
    end
  end
end
