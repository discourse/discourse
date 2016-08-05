require 'execjs'
require 'babel/transpiler'
require 'mini_racer'

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
      # timeout any eval that takes longer than 15 seconds
      ctx = MiniRacer::Context.new(timeout: 15000)
      ctx.eval("var self = this; #{File.read(Babel::Transpiler.script_path)}")
      ctx.eval("module = {}; exports = {};");
      ctx.load("#{Rails.root}/lib/es6_module_transpiler/support/es6-module-transpiler.js")
      ctx.attach("rails.logger.info", proc{|err| Rails.logger.info(err.to_s)})
      ctx.attach("rails.logger.error", proc{|err| Rails.logger.error(err.to_s)})
      ctx.eval <<JS
      console = {
        prefix: "",
        log: function(msg){ rails.logger.info(console.prefix + msg); },
        error: function(msg){ rails.logger.error(console.prefix + msg); }
      }
JS
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
      @mutex.synchronize do
        yield
      end
    end

    def whitelisted?(path)

      @@whitelisted ||= Set.new(
        ["discourse/models/nav-item",
         "discourse/models/user-action",
         "discourse/routes/discourse",
         "discourse/models/category",
         "discourse/models/trust-level",
         "discourse/models/site",
         "discourse/models/user",
         "discourse/models/session",
         "discourse/models/model",
         "discourse/models/topic",
         "discourse/models/post",
         "discourse/views/grouped"]
      )

      @@whitelisted.include?(path) || path =~ /discourse\/mixins/
    end

    def babel_transpile(source)
      klass = self.class
      klass.protect do
        klass.v8.eval("console.prefix = 'BABEL: babel-eval: ';")
        @output = klass.v8.eval(babel_source(source))
      end
    end

    def module_transpile(source, root_path, logical_path)
      klass = self.class
      klass.protect do
        klass.v8.eval("console.prefix = 'BABEL: babel-eval: ';")

        transpiled = babel_source(source)

        compiler_source = "new module.exports.Compiler(#{transpiled}, '#{module_name(root_path, logical_path)}', #{compiler_options}).#{compiler_method}()"

        @output = klass.v8.eval(compiler_source)
      end
    end

    def evaluate(scope, locals, &block)
      return @output if @output

      klass = self.class
      klass.protect do
        klass.v8.eval("console.prefix = 'BABEL: #{scope.logical_path}: ';")
        @output = klass.v8.eval(generate_source(scope))
      end

      # For backwards compatibility with plugins, for now export the Global format too.
      # We should eventually have an upgrade system for plugins to use ES6 or some other
      # resolve based API.
      if whitelisted?(scope.logical_path) &&
        scope.logical_path =~ /(discourse|admin)\/(controllers|components|views|routes|mixins|models)\/(.*)/

        type = Regexp.last_match[2]
        file_name = Regexp.last_match[3].gsub(/[\-\/]/, '_')
        class_name = file_name.classify

        # Rails removes pluralization when calling classify
        if file_name.end_with?('s') && (!class_name.end_with?('s'))
          class_name << "s"
        end
        require_name = module_name(scope.root_path, scope.logical_path)

        if require_name !~ /\-test$/ && require_name !~ /^discourse\/plugins\//
          result = "#{class_name}#{type.classify}"

          # HAX
          result = "Controller" if result == "ControllerController"
          result = "Route" if result == "DiscourseRoute"
          result = "View" if result == "ViewView"

          result.gsub!(/Mixin$/, '')
          result.gsub!(/Model$/, '')

          if result != "PostMenuView"
            @output << "\n\nDiscourse.#{result} = require('#{require_name}').default;\n"
          end
        end
      end

      @output
    end

    def babel_source(source)
      js_source = ::JSON.generate(source, quirks_mode: true)
      "babel.transform(#{js_source}, {ast: false, whitelist: ['es6.constants', 'es6.properties.shorthand', 'es6.arrowFunctions', 'es6.blockScoping', 'es6.destructuring', 'es6.spread', 'es6.parameters', 'es6.templateLiterals', 'es6.regex.unicode', 'es7.decorators', 'es6.classes']})['code']"
    end

    private

    def generate_source(scope)
      js_source = babel_source(data)
      "new module.exports.Compiler(#{js_source}, '#{module_name(scope.root_path, scope.logical_path)}', #{compiler_options}).#{compiler_method}()"
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
