# frozen_string_literal: true

class PenaltyCountsSerializer < ApplicationSerializer
  attributes :silenced, :suspended, :total

  def total
    object.silenced + object.suspended
  end

  def silenced
    object.silenced
  end

  def suspended
    object.suspended
  end
end
