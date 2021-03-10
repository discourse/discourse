# frozen_string_literal: true

require 'stylesheet/common'
require 'stylesheet/importer'
require 'stylesheet/functions'

module Stylesheet

  class Compiler

    def self.compile_asset(asset, options = {})
      importer = Importer.new(options)
      file = importer.prepended_scss

      if Importer::THEME_TARGETS.include?(asset.to_s)
        filename = "theme_#{options[:theme_id]}.scss"
        file += options[:theme_variables].to_s
        file += importer.theme_import(asset)
      elsif Importer.special_imports[asset.to_s]
        filename = "theme_#{options[:theme_id]}.scss"
        file += " @import \"#{asset}\";"
      else
        filename = "#{asset}.scss"
        path = "#{Stylesheet::Common::ASSET_ROOT}/#{filename}"
        file += File.read path

        case asset.to_s
        when "desktop", "mobile"
          file += importer.category_backgrounds
          file += importer.font
        when "embed", "publish"
          file += importer.font
        when "wizard"
          file += importer.wizard_fonts
        end

        if asset.to_s == Stylesheet::Manager::COLOR_SCHEME_STYLESHEET
          file += importer.import_color_definitions
          file += importer.import_wcag_overrides
        end
      end

      compile(file, filename, options)
    end

    def self.compile(stylesheet, filename, options = {})
      source_map_file = options[:source_map_file] || "#{filename.sub(".scss", "")}.css.map"

      load_paths = [Stylesheet::Common::ASSET_ROOT]
      load_paths += options[:load_paths] if options[:load_paths]

      engine = SassC::Engine.new(stylesheet,
                                 importer: Importer,
                                 filename: filename,
                                 style: :compressed,
                                 source_map_file: source_map_file,
                                 source_map_contents: true,
                                 theme_id: options[:theme_id],
                                 theme: options[:theme],
                                 theme_field: options[:theme_field],
                                 color_scheme_id: options[:color_scheme_id],
                                 load_paths: load_paths)

      result = engine.render

      if options[:rtl]
        require 'r2'
        [R2.r2(result), nil]
      else
        source_map = engine.source_map
        source_map.force_encoding("UTF-8")

        [result, source_map]
      end
    end
  end
end
