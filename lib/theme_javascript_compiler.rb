# frozen_string_literal: true

class ThemeJavascriptCompiler
  COLOCATED_CONNECTOR_REGEX =
    %r{\A(?<prefix>.*/?)connectors/(?<outlet>[^/]+)/(?<name>[^/\.]+)\.(?<extension>.+)\z}

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
    @output_tree = []
    @theme_name = theme_name
    @minify = minify
    @settings = settings
  end

  def compile!
    if !@compiled
      @compiled = true
      @output_tree.freeze

      output =
        if !has_content?
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

  # def raw_content
  #   @output_tree.map { |filename, source| source }.join("")
  # end

  def has_content?
    @output_tree.present?
  end

  def append_tree(tree, include_variables: true)
    # Replace legacy extensions
    tree.transform_keys! do |filename|
      if filename.ends_with? ".js.es6"
        filename.sub(/\.js\.es6\z/, ".js")
      else
        filename
      end
    end

    # Transpile and write to output
    tree.each_pair { |filename, content| @output_tree << [filename, content] }
  end

  def append_js_error(filename, message)
    message = "[THEME #{@theme_id} '#{@theme_name}'] Compile error: #{message}"
    append_raw_script filename, "console.error(#{message.to_json});"
  end

  private

  def theme_settings
    <<~JS
      const settings = require("discourse/lib/theme-settings-store")
        .getObjectForTheme(#{@theme_id});
      const themePrefix = (key) => `theme_translations.#{@theme_id}.${key}`;
    JS
  end
end
