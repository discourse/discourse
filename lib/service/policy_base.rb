# frozen_string_literal: true

class Service::PolicyBase
  attr_reader :context

  delegate :guardian, to: :context

  def initialize(context)
    @context = context
  end

  def call
    raise NotImplementedError
  end

  def reason
    raise NotImplementedError
  end
end
