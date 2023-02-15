# frozen_string_literal: true

module Chat
  module ServiceMatchers
    class FailStep
      attr_reader :name, :result

      def initialize(name)
        @name = name
      end

      def matches?(result)
        @result = result
        step_exists? && step_failed? && service_failed?
      end

      def failure_message
        message =
          if !step_exists?
            "Expected #{type} '#{name}' (key: '#{step}') was not found in the result object."
          elsif !step_failed?
            "Expected #{type} '#{name}' (key: '#{step}') to fail but it succeeded."
          else
            "expected the service to fail but it succeeded."
          end
        error_message_with_inspection(message)
      end

      def failure_message_when_negated
        message = "Expected #{type} '#{name}' (key: '#{step}') to succeed but it failed."
        error_message_with_inspection(message)
      end

      def description
        "fail a #{type} named '#{name}'"
      end

      private

      def step_exists?
        result[step].present?
      end

      def step_failed?
        result[step].failure?
      end

      def service_failed?
        result.failure?
      end

      def type
        self.class.name.split("::").last.sub("Fail", "").downcase
      end

      def step
        "result.#{type}.#{name}"
      end

      def error_message_with_inspection(message)
        inspector = StepsInspector.new(result)
        "#{message}\n\n#{inspector.inspect}\n\n#{inspector.error}"
      end
    end

    class FailContract < FailStep
    end

    class FailPolicy < FailStep
    end

    class FailToFindModel < FailStep
      def type
        "model"
      end

      def description
        "fail to find a model named '#{name}'"
      end
    end

    def fail_a_policy(name)
      FailPolicy.new(name)
    end

    def fail_a_contract(name = "default")
      FailContract.new(name)
    end

    def fail_to_find_a_model(name = "model")
      FailToFindModel.new(name)
    end

    def inspect_steps(result)
      inspector = Chat::StepsInspector.new(result)
      puts "Steps:"
      puts inspector.inspect
      puts "\nFirst error:"
      puts inspector.error
    end
  end
end
