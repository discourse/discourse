# frozen_string_literal: true

class Service::PolicyBase
  attr_reader :context

  delegate :guardian, to: :context

  def initialize(context)
    @context = context
  end

  def call
    raise "Not implemented"
  end

  def reason
    raise "Not implemented"
  end
end
