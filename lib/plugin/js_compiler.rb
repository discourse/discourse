# frozen_string_literal: true

class Plugin::JsCompiler
  def initialize(
    plugin_name,
    minify: true,
    tree: {},
    entrypoints: {},
    filename_prefix: nil,
    filename_suffix: nil
  )
    @plugin_name = plugin_name
    @tree = tree
    @entrypoints = entrypoints
    @minify = minify
    @filename_prefix = filename_prefix
    @filename_suffix = filename_suffix
  end

  def compile!
    AssetProcessor.new.rollup(
      @tree,
      {
        pluginName: @plugin_name,
        minify: @minify,
        entrypoints: @entrypoints,
        filenamePrefix: @filename_prefix,
        filenameSuffix: @filename_suffix,
      },
    )
  rescue AssetProcessor::TranspileError => e
    message = "[PLUGIN #{@plugin_name}] Compile error: #{e.message}"
    { "main.js": { "code" => "throw new Error(#{message.to_json});\n", "map" => nil } }
  end
end
