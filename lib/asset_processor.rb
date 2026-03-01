# frozen_string_literal: true

class AssetProcessor
  PROCESSOR_DIR = "tmp/asset-processor"
  LOCK_FILE = "#{PROCESSOR_DIR}/build.lock"

  CACHE_DEPENDENCY_GLOBS = %w[
    node_modules/.pnpm/lock.yaml
    frontend/asset-processor/**/*.js
    frontend/discourse/lib/babel-transform-module-renames.js
    frontend/discourse/config/targets.js
    frontend/discourse-plugins/transform-action-syntax.js
  ]

  @mutex = Mutex.new
  @ctx_init = Mutex.new

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

  def self.inputs_digest
    digest = Digest::MD5.new

    CACHE_DEPENDENCY_GLOBS.each do |pattern|
      files = Dir.glob(pattern).sort
      raise "No files matched #{pattern}" if files.empty?

      files.each do |file|
        digest.update(file)
        digest.update(File.read(file))
      end
    end

    digest.hexdigest.to_i(16).to_s(36) # base36
  end

  def self.processor_file_path
    "#{PROCESSOR_DIR}/asset-processor-#{inputs_digest}.js"
  end

  def self.with_file_lock(&block)
    lock_path = "#{Rails.root}/#{LOCK_FILE}"
    FileUtils.mkdir_p(File.dirname(lock_path))
    File.open(lock_path, File::CREAT | File::RDWR) do |lock_file|
      lock_file.flock(File::LOCK_EX)
      yield
    end
  end

  def self.cleanup_old_cache_files
    Dir
      .glob("#{PROCESSOR_DIR}/asset-processor-*.js")
      .reject { it.end_with?(processor_file_path) }
      .each { File.delete(it) }
  end

  def self.load_or_build_processor_source
    cache_path = processor_file_path

    if File.exist?(cache_path)
      File.read(cache_path)
    else
      with_file_lock do
        if File.exist?(cache_path)
          File.read(cache_path)
        else
          built_source = build_asset_processor
          FileUtils.mkdir_p(PROCESSOR_DIR)
          File.write(cache_path, built_source)
          cleanup_old_cache_files
          built_source
        end
      end
    end
  end

  def self.create_new_context
    # timeout any eval that takes longer than 15 seconds
    ctx = MiniRacer::Context.new(timeout: 15_000, ensure_gc_after_idle: 2000)

    # General shims
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

    source = load_or_build_processor_source

    ctx.eval("globalThis.ROLLUP_PLUGIN_COMPILER = #{ENV["ROLLUP_PLUGIN_COMPILER"].to_json}")
    ctx.eval(source, filename: "asset-processor.js")

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
