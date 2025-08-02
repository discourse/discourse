# frozen_string_literal: true

RSpec::Matchers.define :have_constant do |const|
  match { |owner| owner.const_defined?(const) }

  failure_message { |owner| "expected #{owner} to have a constant #{const}" }

  failure_message_when_negated do |owner|
    "expected #{owner} not to have a constant #{const}, but it does"
  end
end
