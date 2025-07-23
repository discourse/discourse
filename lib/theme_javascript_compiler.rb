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

      output_tree = compile_tree!

      output =
        if !output_tree.present?
          { "code" => "" }
        else
          DiscourseJsProcessor::Transpiler.new.rollup(
            @output_tree.to_h,
            { themeId: @theme_id, settings: @settings },
          )
        end

      @content = output["code"]
      @source_map = output["map"]
    end
    [@content, @source_map]
  rescue DiscourseJsProcessor::TranspileError => e
    message = "[THEME #{@theme_id} '#{@theme_name}'] Compile error: #{e.message}"
    @content = "console.error(#{message.to_json});\n"
    [@content, @source_map]
  end

  def terser_config
    # Based on https://github.com/ember-cli/ember-cli-terser/blob/28df3d90a5/index.js#L12-L26
    {
      sourceMap: {
        includeSources: true,
        root: "theme-#{@theme_id}/",
      },
      compress: {
        negate_iife: false,
        sequences: 30,
        drop_debugger: false,
      },
      output: {
        semicolons: false,
      },
    }
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
