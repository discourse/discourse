# frozen_string_literal: true

CONTRACT_FAILED_ERROR = ->(context) { <<~ERROR }
  Contract failed
  ---------------
  #{context.contract.errors.full_messages.join("\n")}

  ERROR

RSpec::Matchers.define :succeed do
  match { |context| context.success? === true }

  failure_message { |context| CONTRACT_FAILED_ERROR.call(context) if context[:"contract.failed"] }
end

RSpec::Matchers.define :fail_contract_with_error do |error|
  match do |context|
    context.failure? === true && context[:"contract.failed"] &&
      context.contract.errors.full_messages.include?(error)
  end

  failure_message do |context|
    "Expected `#{error}` got `#{context.contract.errors.full_messages.join(",")}`"
  end
end
