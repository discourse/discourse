# frozen_string_literal: true

CONTRACT_FAILED_ERROR = ->(context) { <<~ERROR }
  Contract failed
  ---------------

  #{context.contract.errors.full_messages.join("\n")}
  ERROR

GUARDIAN_FAILED_ERROR = ->(context) { <<~ERROR }
  Guardian failed
  ---------------

  Action `#{context["guardian.failed"]}` was not allowed for user: `#{context.guardian.user.username}`
  ERROR

def handle_failures(context)
  if context["guardian.failed"]
    GUARDIAN_FAILED_ERROR.call(context)
  else
    CONTRACT_FAILED_ERROR.call(context)
  end
end

RSpec::Matchers.define :succeed do
  match { |context| context.success? === true }

  failure_message { |context| handle_failures(context) }
end

RSpec::Matchers.define :fail_contract_with_error do |error|
  match do |context|
    context.failure? && context[:"contract.failed"] &&
      context.contract&.errors&.full_messages&.include?(error)
  end

  failure_message do |context|
    if !context.contract&.errors
      if context[:"guardian.failed"]
        return "Expected `#{error}` got guardian failure for check `#{context[:"guardian.failed"]}`"
      end

      return "Expected `#{error}` got undefined behaviour with no error message."
    end

    "Expected `#{error}` got `#{context.contract.errors.full_messages.join(",")}`"
  end
end

RSpec::Matchers.define :fail_guardian_check do |error|
  match do |context|
    context.failure? && context[:"guardian.failed"] && context[:"guardian.failed"] == error
  end

  failure_message { |context| "Expected `#{error}` got `#{context[:"guardian.failed"]}`" }
end

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

    def fail_a_policy(name)
      FailPolicy.new(name)
    end

    def fail_a_contract(name = "default")
      FailContract.new(name)
    end
  end
end
