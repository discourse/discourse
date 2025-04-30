# frozen_string_literal: true
require "execjs"
require "mini_racer"

class DiscourseJsProcessor
  class TranspileError < StandardError
  end

  def self.transpile(data, root_path, logical_path, theme_id: nil, extension: nil)
    transpiler = Transpiler.new(skip_module: skip_module?(data))
    transpiler.perform(data, root_path, logical_path, theme_id: theme_id, extension: extension)
  end

  def self.skip_module?(data)
    !!(data.present? && data =~ %r{^// discourse-skip-module$})
  end

  class Transpiler
    TRANSPILER_PATH = "tmp/theme-transpiler.js"

    @mutex = Mutex.new
    @ctx_init = Mutex.new
    @processor_mutex = Mutex.new

    def self.mutex
      @mutex
    end

    def self.build_theme_transpiler
      FileUtils.rm_rf("tmp/theme-transpiler") # cleanup old files - remove after Jan 2025
      Discourse::Utils.execute_command(
        "pnpm",
        "-C=app/assets/javascripts/theme-transpiler",
        "node",
        "build.js",
      )
    end

    def self.build_production_theme_transpiler
      File.write(TRANSPILER_PATH, build_theme_transpiler)
      TRANSPILER_PATH
    end

    def self.create_new_context
      # timeout any eval that takes longer than 15 seconds
      ctx = MiniRacer::Context.new(timeout: 15_000, ensure_gc_after_idle: 2000)

      # General shims
      ctx.attach("rails.logger.info", proc { |err| Rails.logger.info(err.to_s) })
      ctx.attach("rails.logger.warn", proc { |err| Rails.logger.warn(err.to_s) })
      ctx.attach("rails.logger.error", proc { |err| Rails.logger.error(err.to_s) })

      source =
        if Rails.env.production?
          File.read(TRANSPILER_PATH)
        else
          @processor_mutex.synchronize { build_theme_transpiler }
        end

      ctx.eval(source, filename: "theme-transpiler.js")

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

    def post_css(css:, map:, source_map_file:)
      self.class.v8_call(
        "postCss",
        css,
        map,
        source_map_file,
        fetch_result_call: "getPostCssResult",
      )
    end
  end
end
