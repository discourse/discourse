require 'execjs'

module Tilt
  class ES6ModuleTranspilerTemplate < Tilt::Template
    self.default_mime_type = 'application/javascript'

    @mutex = Mutex.new
    @ctx_init = Mutex.new

    def prepare
      # intentionally left empty
      # Tilt requires this method to be defined
    end

    def self.create_new_context
      ctx = V8::Context.new(timeout: 5000)
      ctx.eval("module = {}; exports = {};");
      ctx.load("#{Rails.root}/lib/es6_module_transpiler/support/es6-module-transpiler.js")
      ctx
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

    class JavaScriptError < StandardError
      attr_accessor :message, :backtrace

      def initialize(message, backtrace)
        @message = message
        @backtrace = backtrace
      end

    end

    def self.protect
      rval = nil
      @mutex.synchronize do
        begin
          rval = yield
          # This may seem a bit odd, but we don't want to leak out
          # objects that require locks on the v8 vm, to get a backtrace
          # you need a lock, if this happens in the wrong spot you can
          # deadlock a process
        rescue V8::Error => e
          raise JavaScriptError.new(e.message, e.backtrace)
        end
      end
      rval
    end

    def evaluate(scope, locals, &block)
      return @output if @output

      klass = self.class
      klass.protect do
        @output = klass.v8.eval(generate_source(scope))
      end

      source = @output.dup

      # For backwards compatibility with plugins, for now export the Global format too.
      # We should eventually have an upgrade system for plugins to use ES6 or some other
      # resolve based API.
      if ENV['DISCOURSE_NO_CONSTANTS'].nil? && scope.logical_path =~ /(discourse|admin)\/(controllers|components|views|routes)\/(.*)/
        type = Regexp.last_match[2]
        file_name = Regexp.last_match[3].gsub(/[\-\/]/, '_')
        class_name = file_name.classify

        # Rails removes pluralization when calling classify
        if file_name.end_with?('s') && (!class_name.end_with?('s'))
          class_name << "s"
        end
        require_name = module_name(scope.root_path, scope.logical_path)
        @output << "\n\nDiscourse.#{class_name}#{type.classify} = require('#{require_name}').default"
      end

      # Include JS code for JSHint
      unless Rails.env.production?
        req_path = "/assets/#{scope.logical_path}.js"
        @output << "\nwindow.__jshintSrc = window.__jshintSrc || {}; window.__jshintSrc['#{req_path}'] = #{source.to_json};\n"
      end

      @output
    end

    private

    def generate_source(scope)
      "new module.exports.Compiler(#{::JSON.generate(data, quirks_mode: true)}, '#{module_name(scope.root_path, scope.logical_path)}', #{compiler_options}).#{compiler_method}()"
    end

    def module_name(root_path, logical_path)
      path = nil

      root_base = File.basename(Rails.root)
      # If the resource is a plugin, use the plugin name as a prefix
      if root_path =~ /(.*\/#{root_base}\/plugins\/[^\/]+)\//
        plugin_path = "#{Regexp.last_match[1]}/plugin.rb"

        plugin = Discourse.plugins.find {|p| p.path == plugin_path }
        path = "discourse/plugins/#{plugin.name}/#{logical_path.sub(/javascripts\//, '')}" if plugin
      end

      path ||= logical_path
      if ES6ModuleTranspiler.transform
        path = ES6ModuleTranspiler.transform.call(path)
      end

      path
    end

    def compiler_method
      type = {
        amd: 'AMD',
        cjs: 'CJS',
        globals: 'Globals'
      }[ES6ModuleTranspiler.compile_to.to_sym]

      "to#{type}"
    end

    def compiler_options
      ::JSON.generate(ES6ModuleTranspiler.compiler_options, quirks_mode: true)
    end
  end
end
