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

RSpec::Matchers.define :be_a_success do
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
