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

  def initialize(theme_id, theme_name, settings = {}, minify: true)
    @theme_id = theme_id
    @input_tree = {}
    @theme_name = theme_name
    @minify = minify
    @settings = settings
  end

  def compile!
    if !@compiled
      @compiled = true
      @input_tree.freeze

      output =
        AssetProcessor.new.rollup(
          @input_tree.transform_keys { |k| k.sub(/\.js\.es6$/, ".js") },
          { themeId: @theme_id, settings: @settings, minify: @minify && !@@terser_disabled },
        )

      @content = output["code"]
      @source_map = output["map"]
    end
    [@content, @source_map]
  rescue AssetProcessor::TranspileError => e
    message = "[THEME #{@theme_id} '#{@theme_name}'] Compile error: #{e.message}"
    @content = "throw new Error(#{message.to_json});\n"
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

  def append_tree(tree)
    @input_tree.merge!(tree)
  end
end
