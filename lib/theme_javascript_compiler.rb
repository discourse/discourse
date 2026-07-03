# frozen_string_literal: true

class ThemeJavascriptCompiler
  class CompileError < StandardError
  end

  @@terser_disabled = false
  def self.disable_terser!
    raise "Tests only" if !Rails.env.test?
    @@terser_disabled = true
  end

  def self.enable_terser!
    raise "Tests only" if !Rails.env.test?
    @@terser_disabled = false
  end

  def initialize(theme_id, theme_name, minify: true)
    @theme_id = theme_id
    @input_tree = {}
    @theme_name = theme_name
    @minify = minify
  end

  def compile!
    if !@compiled
      @compiled = true
      @input_tree =
        @input_tree.to_h do |k, v|
          if k.end_with?(".js.es6")
            [k.sub(/\.js\.es6$/, ".js"), AssetProcessor.append_es6_deprecation(v, k)]
          else
            [k, v]
          end
        end
      @input_tree.freeze

      output =
        AssetProcessor.new.rollup(
          @input_tree,
          {
            themeId: @theme_id,
            minify: @minify && !@@terser_disabled,
            entrypoints: {
              main: {
                modules: @input_tree.keys,
              },
            },
          },
        )

      main = output.values.find { |chunk| chunk["name"] == "main" }
      @content = main["code"]
      @source_map = main["map"]
      @external_plugin_imports = main["externalPluginImports"] || []
    end
    [@content, @source_map]
  rescue AssetProcessor::TranspileError => e
    message = "[THEME #{@theme_id} '#{@theme_name}'] Compile error: #{e.message}"
    @content = "throw new Error(#{message.to_json});\n"
    @external_plugin_imports = []
    [@content, @source_map]
  end

  def content
    compile!
    @content
  end

  def source_map
    compile!
    @source_map
  end

  def external_plugin_imports
    compile!
    @external_plugin_imports
  end

  def append_tree(tree)
    @input_tree.merge!(tree)
  end
end
