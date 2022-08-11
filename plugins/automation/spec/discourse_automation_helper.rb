# frozen_string_literal: true

require 'rails_helper'

def capture_contexts(&blk)
  DiscourseAutomation::CapturedContext.capture(&blk)
end

module DiscourseAutomation::CapturedContext
  def self.add(context)
    @contexts << context
  end

  def self.capture
    raise StandardError, "Nested capture is not supported" if @capturing
    raise StandardError, "Expecting a block" if !block_given?
    @capturing = true
    @contexts = []
    yield
    @contexts
  ensure
    @capturing = false
  end

end

DiscourseAutomation::Scriptable.add('something_about_us') do
  script { |context| DiscourseAutomation::CapturedContext.add(context); nil }
  triggerables [DiscourseAutomation::Triggerable::API_CALL]
end

DiscourseAutomation::Scriptable.add('nothing_about_us') do
  triggerables [DiscourseAutomation::Triggerable::API_CALL]
end
