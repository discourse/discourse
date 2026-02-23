# frozen_string_literal: true

class Plugin::JsCompiler
  def initialize(plugin_name, minify: true, tree: {}, entrypoints: {})
    @plugin_name = plugin_name
    @tree = tree
    @entrypoints = entrypoints
    @minify = minify
  end

  def compile!
    AssetProcessor.new.rollup(
      @tree,
      {
        pluginName: @plugin_name,
        minify: @minify && !@@terser_disabled,
        entrypoints: @entrypoints,
      },
    )
  rescue AssetProcessor::TranspileError => e
    message = "[PLUGIN #{@plugin_name}] Compile error: #{e.message}"
    { "main.js": { "code" => "throw new Error(#{message.to_json});\n", "map" => nil } }
  end
end
