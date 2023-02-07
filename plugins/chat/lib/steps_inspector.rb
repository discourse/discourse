# frozen_string_literal: true

module Chat
  class StepsInspector
    class Step
      attr_reader :step, :result, :nesting_level

      delegate :name, to: :step
      delegate :failure?, :success?, to: :step_result, allow_nil: true

      def self.for(step, result, nesting_level: 0)
        class_name =
          "#{module_parent_name}::#{step.class.name.split("::").last.sub(/^(\w+)Step$/, "\\1")}"
        class_name.constantize.new(step, result, nesting_level: nesting_level)
      end

      def initialize(step, result, nesting_level: 0)
        @step = step
        @result = result
        @nesting_level = nesting_level
      end

      def type
        self.class.name.split("::").last.downcase
      end

      def emoji
        return "❌" if failure?
        return "✅" if success?
        ""
      end

      def error
        ""
      end

      def steps
        [self]
      end

      def inspect
        "#{"  " * nesting_level}[#{type}] '#{name}' #{emoji}"
      end

      private

      def step_result
        nil
      end
    end

    class Model < Step
      def step_result
        result[:"result.#{name}"]
      end

      def success?
        result[name]
      end

      def error
        step_result.exception.full_message
      end
    end

    class Contract < Step
      def step_result
        result[:"result.contract.#{name}"]
      end

      def error
        step_result.errors.inspect
      end
    end

    class Policy < Step
      def step_result
        result[:"result.policy.#{name}"]
      end
    end

    class Transaction < Step
      def steps
        [self, *step.steps.map { Step.for(_1, result, nesting_level: nesting_level + 1).steps }]
      end

      def inspect
        "#{"  " * nesting_level}[#{type}]"
      end
    end

    attr_reader :steps, :result

    def initialize(result)
      @steps = result.__steps__.map { Step.for(_1, result).steps }.flatten
      @result = result
    end

    def inspect
      steps
        .map
        .with_index { |step, index| "[#{index + 1}/#{steps.size}] #{step.inspect}" }
        .join("\n")
    end

    def error
      steps.detect(&:failure?)&.error
    end
  end
end
