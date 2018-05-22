class PenaltyCountsSerializer < ApplicationSerializer
  attributes :silenced, :suspended

  def silenced
    object.silenced
  end

  def suspended
    object.suspended
  end
end
