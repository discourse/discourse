require_dependency 'stylesheet/common'
require_dependency 'stylesheet/importer'
require_dependency 'stylesheet/functions'

module Stylesheet

  class Compiler

    def self.error_as_css(error, label)
      error = error.message
      error.gsub!("\n", '\A ')
      error.gsub!("'", '\27 ')

      "#main { display: none; }
      body { white-space: pre; }
      body:before { font-family: monospace; content: '#{error}' }"
    end

    def self.compile_asset(asset, options = {})

      if Importer.special_imports[asset.to_s]
        filename = "theme.scss"
        file = "@import \"theme_variables\"; @import \"#{asset}\";"
      else
        filename = "#{asset}.scss"
        path = "#{ASSET_ROOT}/#{filename}"
        file = File.read path
      end

      compile(file, filename, options)

    end

    def self.compile(stylesheet, filename, options = {})
      source_map_file = options[:source_map_file] || "#{filename.sub(".scss", "")}.css.map"

      engine = SassC::Engine.new(stylesheet,
                                 importer: Importer,
                                 filename: filename,
                                 style: :compressed,
                                 source_map_file: source_map_file,
                                 source_map_contents: true,
                                 theme_id: options[:theme_id],
                                 theme: options[:theme],
                                 theme_field: options[:theme_field],
                                 load_paths: [ASSET_ROOT])

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
