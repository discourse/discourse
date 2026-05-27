# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class OnlyIfStep < Step
      include StepsHelpers

      attr_reader :steps

      def initialize(name, &block)
        super(name)
        @steps = []
        instance_exec(&block)
      end

      def run_step
        return context[result_key][:skipped?] = true unless super
        steps.each { |step| step.call(instance, context) }
      end
    end
  end
end
