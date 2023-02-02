# frozen_string_literal: true
module Chat
  module ServiceMatchers
    class FailAction
      attr_reader :name, :result

      def initialize(name)
        @name = name
      end

      def matches?(result)
        @result = result
        action_exists? && action_failed? && service_failed?
      end

      def action_exists?
        result[action].present?
      end

      def action_failed?
        result[action].failure?
      end

      def service_failed?
        result.failure?
      end

      def failure_message
        return "expected action '#{action}' does not exist" unless action_exists?
        return "expected action '#{action}' to fail" unless action_failed?
        "expected the service to fail but it succeeded"
      end
    end

    class FailContract < FailAction
      attr_reader :error_message

      def action
        "result.contract.#{@name}"
      end

      def matches?(service)
        super && has_error? && matches_error?
      end

      def has_error?
        result[action].errors.present?
      end

      def failure_message
        return "expected contract '#{action}' to have errors" unless has_error?
        super
      end

      def description
        "fail a contract"
      end

      def with_error(error)
        @error_message = error
        self
      end

      def matches_error?
        return true if error_message.blank?
        result[action].errors.full_messages.include?(error_message)
      end
    end

    class FailPolicy < FailAction
      def action
        "result.policy.#{@name}"
      end

      def description
        "fail a policy"
      end
    end

    class FailToFindModel < FailAction
      def action
        "result.#{@name}"
      end

      def description
        "fail to find a model"
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
  end
end
