# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class Step
      class DefaultValuesNotAllowed < StandardError
      end

      attr_reader :name, :method_name, :class_name

      def initialize(name, method_name = name, class_name: nil)
        @name, @method_name, @class_name = name, method_name, class_name
        @instance = Concurrent::ThreadLocalVar.new
        @context = Concurrent::ThreadLocalVar.new
      end

      def call(instance, context)
        @instance.value, @context.value = instance, context
        context[result_key] = Context.build
        with_runtime { run_step }
      end

      def result_key
        "result.#{type}.#{name}"
      end

      def instance = @instance.value

      def context = @context.value

      private

      def run_step
        object = class_name&.new(context)
        method = object&.method(:call) || instance.method(method_name)
        if !object && method.parameters.any? { it[0] != :keyreq }
          raise DefaultValuesNotAllowed,
                "In #{type} '#{name}': default values in step implementations are not allowed. Maybe they could be defined in a params or options block?"
        end
        args = context.slice(*method.parameters.select { it[0] == :keyreq }.map(&:last))
        context[result_key][:object] = object if object
        instance.instance_exec(**args, &method)
      end

      def type
        self.class.name.split("::").last.underscore.sub(/^(\w+)_step$/, "\\1")
      end

      def with_runtime
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield.tap do
          ended_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          context[result_key][:__runtime__] = ended_at - started_at
        end
      end
    end
  end
end
