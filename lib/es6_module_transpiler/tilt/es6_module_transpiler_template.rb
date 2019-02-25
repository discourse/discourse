require 'execjs'
require 'mini_racer'

module Tilt

  class ES6ModuleTranspilerTemplate < Tilt::Template
    self.default_mime_type = 'application/javascript'

    @mutex = Mutex.new
    @ctx_init = Mutex.new

    def self.call(input)
      filename = input[:filename]
      source = input[:data]
      context = input[:environment].context_class.new(input)

      result = new(filename) { source }.render(context)
      context.metadata.merge(data: result)
    end

    def prepare
      # intentionally left empty
      # Tilt requires this method to be defined
    end

    def self.create_new_context
      # timeout any eval that takes longer than 15 seconds
      ctx = MiniRacer::Context.new(timeout: 15000)
      ctx.eval("var self = this; #{File.read("#{Rails.root}/vendor/assets/javascripts/babel.js")}")
      ctx.eval(File.read(Ember::Source.bundled_path_for('ember-template-compiler.js')))
      ctx.eval("module = {}; exports = {};")
      ctx.attach("rails.logger.info", proc { |err| Rails.logger.info(err.to_s) })
      ctx.attach("rails.logger.error", proc { |err| Rails.logger.error(err.to_s) })
      ctx.eval <<JS
      console = {
        prefix: "",
        log: function(msg){ rails.logger.info(console.prefix + msg); },
        error: function(msg){ rails.logger.error(console.prefix + msg); }
      }

JS
      source = File.read("#{Rails.root}/lib/javascripts/widget-hbs-compiler.js.es6")
      js_source = ::JSON.generate(source, quirks_mode: true)
      js = ctx.eval("Babel.transform(#{js_source}, { ast: false, plugins: ['check-es2015-constants', 'transform-es2015-arrow-functions', 'transform-es2015-block-scoped-functions', 'transform-es2015-block-scoping', 'transform-es2015-classes', 'transform-es2015-computed-properties', 'transform-es2015-destructuring', 'transform-es2015-duplicate-keys', 'transform-es2015-for-of', 'transform-es2015-function-name', 'transform-es2015-literals', 'transform-es2015-object-super', 'transform-es2015-parameters', 'transform-es2015-shorthand-properties', 'transform-es2015-spread', 'transform-es2015-sticky-regex', 'transform-es2015-template-literals', 'transform-es2015-typeof-symbol', 'transform-es2015-unicode-regex'] }).code")
      ctx.eval(js)

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
        transpiled = babel_source(
          source,
          module_name: module_name(root_path, logical_path),
          filename: logical_path
        )
        @output = klass.v8.eval(transpiled)
      end
    end

    def evaluate(scope, locals, &block)
      return @output if @output

      klass = self.class
      klass.protect do
        klass.v8.eval("console.prefix = 'BABEL: #{scope.logical_path}: ';")

        source = babel_source(
          data,
          module_name: module_name(scope.root_path, scope.logical_path),
          filename: scope.logical_path
        )

        @output = klass.v8.eval(source)
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

    def babel_source(source, opts = nil)
      opts ||= {}

      js_source = ::JSON.generate(source, quirks_mode: true)

      if opts[:module_name] && transpile_into_module?
        filename = opts[:filename] || 'unknown'
        "Babel.transform(#{js_source}, { moduleId: '#{opts[:module_name]}', filename: '#{filename}', ast: false, presets: ['es2015'], plugins: [['transform-es2015-modules-amd', {noInterop: true}], 'transform-decorators-legacy', exports.WidgetHbsCompiler] }).code"
      else
        "Babel.transform(#{js_source}, { ast: false, plugins: ['check-es2015-constants', 'transform-es2015-arrow-functions', 'transform-es2015-block-scoped-functions', 'transform-es2015-block-scoping', 'transform-es2015-classes', 'transform-es2015-computed-properties', 'transform-es2015-destructuring', 'transform-es2015-duplicate-keys', 'transform-es2015-for-of', 'transform-es2015-function-name', 'transform-es2015-literals', 'transform-es2015-object-super', 'transform-es2015-parameters', 'transform-es2015-shorthand-properties', 'transform-es2015-spread', 'transform-es2015-sticky-regex', 'transform-es2015-template-literals', 'transform-es2015-typeof-symbol', 'transform-es2015-unicode-regex', 'transform-regenerator', 'transform-decorators-legacy', exports.WidgetHbsCompiler] }).code"
      end
    end

    private

    def transpile_into_module?
      file.nil? || file.exclude?('.no-module')
    end

    def module_name(root_path, logical_path)
      path = nil

      root_base = File.basename(Rails.root)
      # If the resource is a plugin, use the plugin name as a prefix
      if root_path =~ /(.*\/#{root_base}\/plugins\/[^\/]+)\//
        plugin_path = "#{Regexp.last_match[1]}/plugin.rb"

        plugin = Discourse.plugins.find { |p| p.path == plugin_path }
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
