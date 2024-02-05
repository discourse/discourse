# frozen_string_literal: true
require "execjs"
require "mini_racer"

class DiscourseJsProcessor
  class TranspileError < StandardError
  end

  # To generate a list of babel plugins used by ember-cli, set
  # babel: { debug: true } in ember-cli-build.js, then run `yarn ember build -prod`
  DISCOURSE_COMMON_BABEL_PLUGINS = [
    ["proposal-decorators", { legacy: true }],
    "proposal-class-properties",
    "proposal-private-methods",
    "proposal-class-static-block",
    "transform-parameters",
    "proposal-export-namespace-from",
  ]

  def self.ember_cli?(filename)
    filename.include?("/app/assets/javascripts/discourse/dist/")
  end

  def self.call(input)
    root_path = input[:load_path] || ""
    logical_path =
      (input[:filename] || "").sub(root_path, "").gsub(/\.(js|es6).*$/, "").sub(%r{^/}, "")
    data = input[:data]

    data = transpile(data, root_path, logical_path) if should_transpile?(input[:filename])

    { data: data }
  end

  def self.transpile(data, root_path, logical_path, theme_id: nil, extension: nil)
    transpiler = Transpiler.new(skip_module: skip_module?(data))
    transpiler.perform(data, root_path, logical_path, theme_id: theme_id, extension: extension)
  end

  def self.should_transpile?(filename)
    filename ||= ""

    # skip ember cli
    return false if ember_cli?(filename)

    # es6 is always transpiled
    return true if filename.end_with?(".es6") || filename.end_with?(".es6.erb")

    # For .js check the path...
    return false unless filename.end_with?(".js") || filename.end_with?(".js.erb")

    relative_path = filename.sub(Rails.root.to_s, "").sub(%r{^/*}, "")

    js_root = "app/assets/javascripts"
    test_root = "test/javascripts"

    return false if relative_path.start_with?("#{js_root}/locales/")
    return false if relative_path.start_with?("#{js_root}/plugins/")

    !!(relative_path =~ %r{^#{js_root}/[^/]+/} || relative_path =~ %r{^#{test_root}/[^/]+/})
  end

  def self.skip_module?(data)
    !!(data.present? && data =~ %r{^// discourse-skip-module$})
  end

  class Transpiler
    TRANSPILER_PATH =
      (
        if Rails.env.production?
          "tmp/theme-transpiler.js"
        else
          "tmp/theme-transpiler/#{Process.pid}.js"
        end
      )

    @mutex = Mutex.new
    @ctx_init = Mutex.new
    @processor_mutex = Mutex.new

    def self.mutex
      @mutex
    end

    def self.build_theme_transpiler
      Discourse::Utils.execute_command(
        "node",
        "app/assets/javascripts/theme-transpiler/build.js",
        TRANSPILER_PATH,
      )
      TRANSPILER_PATH
    end

    def self.create_new_context
      # timeout any eval that takes longer than 15 seconds
      ctx = MiniRacer::Context.new(timeout: 15_000, ensure_gc_after_idle: 2000)

      # General shims
      ctx.attach("rails.logger.info", proc { |err| Rails.logger.info(err.to_s) })
      ctx.attach("rails.logger.warn", proc { |err| Rails.logger.warn(err.to_s) })
      ctx.attach("rails.logger.error", proc { |err| Rails.logger.error(err.to_s) })

      # Theme template AST transformation plugins
      @processor_mutex.synchronize { build_theme_transpiler } if !Rails.env.production?

      ctx.eval(File.read(TRANSPILER_PATH), filename: "theme-transpiler.js")

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

    def perform(source, root_path = nil, logical_path = nil, theme_id: nil, extension: nil)
      self.class.v8_call(
        "transpile",
        source,
        {
          skipModule: @skip_module,
          moduleId: module_name(root_path, logical_path),
          filename: logical_path || "unknown",
          extension: extension,
          themeId: theme_id,
          commonPlugins: DISCOURSE_COMMON_BABEL_PLUGINS,
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
        path =
          "discourse/plugins/#{plugin.name}/#{logical_path.sub(%r{javascripts/}, "")}" if plugin
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
  end
end
