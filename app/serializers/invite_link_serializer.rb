# frozen_string_literal: true

class InviteLinkSerializer < ApplicationSerializer
  attributes :id,
             :invite_key,
             :created_at,
             :max_redemptions_allowed,
             :redemption_count,
             :expires_at,
             :group_names

  def group_names
    object.groups.pluck(:name).join(", ")
  end
end
