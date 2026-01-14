# frozen_string_literal: true

class ProblemCheck::Problem
  PRIORITIES = %w[low high].freeze

  attr_reader :message, :priority, :identifier, :target, :details

  def initialize(message, priority: "low", identifier: nil, target: nil, details: {})
    @message = message
    @priority = PRIORITIES.include?(priority) ? priority : "low"
    @identifier = identifier
    @target = target
    @details = details
  end

  def to_s
    @message
  end

  def to_h
    { message:, priority:, identifier:, target: }
  end
  alias_method :attributes, :to_h

  def self.from_h(h)
    h = h.with_indifferent_access

    return if h[:message].blank?

    new(h[:message], priority: h[:priority], identifier: h[:identifier], target: h[:target])
  end
end
