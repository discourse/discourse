# frozen_string_literal: true

class AssetProcessor
  PROCESSOR_PATH = "tmp/asset-processor.js"

  @mutex = Mutex.new
  @ctx_init = Mutex.new
  @processor_mutex = Mutex.new

  class TranspileError < StandardError
  end

  def self.transpile(data, root_path, logical_path, theme_id: nil, extension: nil)
    processor = new(skip_module: skip_module?(data))
    processor.perform(data, root_path, logical_path, theme_id: theme_id, extension: extension)
  end

  def self.skip_module?(data)
    !!(data.present? && data =~ %r{^// discourse-skip-module$})
  end

  def self.mutex
    @mutex
  end

  def self.build_asset_processor
    Discourse::Utils.execute_command("pnpm", "-C=frontend/asset-processor", "node", "build.js")
  end

  def self.build_production_asset_processor
    File.write(PROCESSOR_PATH, build_asset_processor)
    PROCESSOR_PATH
  end

  def self.raw_snapshot
    @raw_snapshot ||=
      begin
        source =
          if Rails.env.production?
            File.read(PROCESSOR_PATH)
          else
            build_asset_processor
          end

        MiniRacer::Snapshot.new(source).dump
      end
  end

  def self.create_new_context
    # timeout any eval that takes longer than 15 seconds
    ctx =
      MiniRacer::Context.new(
        timeout: 15_000,
        ensure_gc_after_idle: 2000,
        snapshot: MiniRacer::Snapshot.load(raw_snapshot),
      )

    ctx.attach(
      "rails.logger.info",
      proc do |err|
        Rails.logger.info(err.to_s)
        nil
      end,
    )
    ctx.attach(
      "rails.logger.warn",
      proc do |err|
        Rails.logger.warn(err.to_s)
        nil
      end,
    )
    ctx.attach(
      "rails.logger.error",
      proc do |err|
        Rails.logger.error(err.to_s)
        nil
      end,
    )
    ctx.eval("globalThis.patchWebAssembly();")

    ctx
  end

  def self.reset_context
    @ctx&.dispose
    @ctx = nil
  end

  def self.v8
    return @ctx if @ctx

    # ensure we only init one of these
    @ctx_init.synchronize do
      return @ctx if @ctx
      @ctx = create_new_context
    end

    @ctx
  end

  # Call a method in the global scope of the v8 context.
  # The `fetch_result_call` kwarg provides a workaround for the lack of mini_racer async
  # result support. The first call can perform some async operation, and then `fetch_result_call`
  # will be called to fetch the result.
  def self.v8_call(*args, **kwargs)
    fetch_result_call = kwargs.delete(:fetch_result_call)
    mutex.synchronize do
      result = v8.call(*args, **kwargs)
      result = v8.call(fetch_result_call) if fetch_result_call
      result
    end
  rescue MiniRacer::RuntimeError => e
    message = e.message
    begin
      # Workaround for https://github.com/rubyjs/mini_racer/issues/262
      possible_encoded_message = message.delete_prefix("Error: ")
      decoded = JSON.parse("{\"value\": #{possible_encoded_message}}")["value"]
      message = "Error: #{decoded}"
    rescue JSON::ParserError
      message = e.message
    end
    transpile_error = TranspileError.new(message)
    transpile_error.set_backtrace(e.backtrace)
    raise transpile_error
  end

  def initialize(skip_module: false)
    @skip_module = skip_module
  end

  def perform(
    source,
    root_path = nil,
    logical_path = nil,
    theme_id: nil,
    extension: nil,
    generate_map: false
  )
    self.class.v8_call(
      "transpile",
      source,
      {
        skipModule: @skip_module,
        moduleId: module_name(root_path, logical_path),
        filename: logical_path || "unknown",
        extension: extension,
        themeId: theme_id,
        generateMap: generate_map,
      },
    )
  end

  def module_name(root_path, logical_path)
    path = nil

    root_base = File.basename(Rails.root)
    # If the resource is a plugin, use the plugin name as a prefix
    if root_path =~ %r{(.*/#{root_base}/plugins/[^/]+)/}
      plugin_path = "#{Regexp.last_match[1]}/plugin.rb"

      plugin = Discourse.plugins.find { |p| p.path == plugin_path }
      path = "discourse/plugins/#{plugin.name}/#{logical_path.sub(%r{javascripts/}, "")}" if plugin
    end

    # We need to strip the app subdirectory to replicate how ember-cli works.
    path || logical_path&.gsub("app/", "")&.gsub("addon/", "")&.gsub("admin/addon", "admin")
  end

  def compile_raw_template(source, theme_id: nil)
    self.class.v8_call("compileRawTemplate", source, theme_id)
  end

  def terser(tree, opts)
    self.class.v8_call("minify", tree, opts, fetch_result_call: "getMinifyResult")
  end

  def rollup(tree, opts)
    self.class.v8_call("rollup", tree, opts, fetch_result_call: "getRollupResult")
  end

  def post_css(css:, map:, source_map_file:)
    self.class.v8_call("postCss", css, map, source_map_file, fetch_result_call: "getPostCssResult")
  end

  def ember_version
    self.class.v8_call("emberVersion")
  end
end
