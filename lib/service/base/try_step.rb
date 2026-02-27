# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class TryStep < Step
      module FilteredBacktrace
        def filtered_backtrace
          Array
            .wrap(backtrace)
            .chunk { it.match?(%r{/(gems|lib/service|ruby)/}) }
            .flat_map do |excluded, lines|
              next "(#{lines.size} framework line(s) excluded)" if excluded
              lines
            end
        end
      end

      include StepsHelpers

      attr_reader :steps, :exceptions

      def initialize(exceptions, &block)
        super("default")
        @steps = []
        @exceptions = exceptions.presence || [StandardError]
        instance_exec(&block)
      end

      def run_step
        steps.each do |step|
          @current_step = step
          step.call(instance, context)
        end
      rescue *exceptions => e
        raise e if e.is_a?(Failure)
        e.singleton_class.prepend(FilteredBacktrace)
        context[@current_step.result_key].fail(raised_exception?: true, exception: e)
        context[result_key][:exception] = e
        context.fail!
      end
    end
  end
end
