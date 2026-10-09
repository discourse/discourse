# frozen_string_literal: true

class ReviewableActionContext < ActiveSupport::CurrentAttributes
  attribute :reviewable, :actor, :action_name, :first_handling, :decision_provenance

  def self.metadata
    return {} unless reviewable

    {
      reviewable_id: reviewable.id,
      actor_id: actor&.id,
      action_name: action_name.to_s,
      first_handling: first_handling,
      decision_provenance: decision_provenance.to_s,
    }
  end
end
