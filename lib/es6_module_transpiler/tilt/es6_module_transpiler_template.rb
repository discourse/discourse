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
      @output
    end

    private

    def generate_source(scope)
      "new module.exports.Compiler(#{::JSON.generate(data, quirks_mode: true)}, '#{module_name(scope.root_path, scope.logical_path)}', #{compiler_options}).#{compiler_method}()"
    end

    def module_name(root_path, logical_path)
      path = ''
      if prefix = ES6ModuleTranspiler.lookup_prefix(File.join(root_path, logical_path))
        path = File.join(prefix, logical_path)
      else
        path = logical_path
      end

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
