# frozen_string_literal: true

RSpec::Matchers.define :have_queue_contents do |*expected|
  match do |queue|
    @actual = []
    @actual << queue.pop(true) until queue.empty?
    @actual == expected
  rescue ThreadError
    @actual == expected
  end

  failure_message do
    "expected queue to have contents #{expected.inspect}, but got #{@actual.inspect}"
  end

  failure_message_when_negated do
    "expected queue not to have contents #{expected.inspect}, but it did"
  end
end
