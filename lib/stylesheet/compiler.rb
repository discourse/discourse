# frozen_string_literal: true

require "stylesheet/importer"

module Stylesheet
  class Compiler
    ASSET_ROOT = "#{Rails.root}/app/assets/stylesheets".freeze unless defined?(ASSET_ROOT)

    def self.compile_asset(asset, options = {})
      importer = Importer.new(options)
      file = importer.prepended_scss

      if Importer::THEME_TARGETS.include?(asset.to_s)
        filename = "theme_#{options[:theme_id]}.scss"
        file += options[:theme_variables].to_s
        file += importer.theme_import(asset)
      elsif plugin_assets = Importer.plugin_assets[asset.to_s]
        filename = "#{asset}.scss"
        options[:load_paths] = [] if options[:load_paths].nil?
        plugin_assets.each do |src|
          file += File.read src
          options[:load_paths] << File.expand_path(File.dirname(src))
        end
      else
        filename = "#{asset}.scss"
        path = "#{ASSET_ROOT}/#{filename}"
        file += File.read path

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

      engine =
        SassC::Engine.new(
          stylesheet,
          filename: filename,
          style: :compressed,
          source_map_file: source_map_file,
          source_map_contents: true,
          load_paths: load_paths,
        )

      result = engine.render

      if options[:rtl]
        require "rtlcss"
        [Rtlcss.flip_css(result), nil]
      else
        source_map = engine.source_map
        source_map.force_encoding("UTF-8")

        [result, source_map]
      end
    end
  end
end
