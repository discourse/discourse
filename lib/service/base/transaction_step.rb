# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class TransactionStep < Step
      include StepsHelpers

      attr_reader :steps

      def initialize(&block)
        super("")
        @steps = []
        instance_exec(&block)
      end

      def run_step
        ActiveRecord::Base.transaction { steps.each { |step| step.call(instance, context) } }
      end
    end
  end
end
