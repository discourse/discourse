# frozen_string_literal: true

class Plugin::JsCompiler
  def initialize(plugin_name, minify: true)
    @plugin_name = plugin_name
    @input_tree = {}
    @minify = minify
  end

  def compile!
    if !@compiled
      @compiled = true
      @input_tree.freeze

      output =
        AssetProcessor.new.rollup(
          @input_tree.transform_keys { |k| k.sub(/\.js\.es6$/, ".js") },
          { pluginName: @plugin_name, minify: @minify && !@@terser_disabled },
        )
      # @processor.call(
      #   "rollup",
      #   @input_tree,
      #   { pluginName: @plugin_name, minify: @minify && !@@terser_disabled },
      # )
      # output = @processor.call("getRollupResult")
      # input_str = {
      #   tree: @input_tree,
      #   opts: {
      #     pluginName: @plugin_name,
      #     minify: @minify && !@@terser_disabled,
      #   },
      # }.to_json.to_s
      # out, err, status =
      #   Open3.capture3(
      #     "node",
      #     "#{Rails.root}/app/assets/javascripts/theme-transpiler/plugin-rollup.js",
      #     stdin_data: input_str,
      #   )

      # puts err
      # output = JSON.parse(out)

      @content = output["code"]
      @source_map = output["map"]
    end
    [@content, @source_map]
  rescue AssetProcessor::TranspileError => e
    message = "[PLUGIN #{@plugin_name}] Compile error: #{e.message}"
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
