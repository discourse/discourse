# frozen_string_literal: true

class ProblemCheck::Problem
  PRIORITIES = %w[low high].freeze

  attr_reader :message, :priority, :identifier

  def initialize(message, priority: "low", identifier: nil)
    @message = message
    @priority = PRIORITIES.include?(priority) ? priority : "low"
    @identifier = identifier
  end

  def to_s
    @message
  end

  def to_h
    { message: message, priority: priority, identifier: identifier }
  end
  alias_method :attributes, :to_h

  def self.from_h(h)
    h = h.with_indifferent_access

    return if h[:message].blank?

    new(h[:message], priority: h[:priority], identifier: h[:identifier])
  end
end
