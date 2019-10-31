# frozen_string_literal: true

class AdminBadgesSerializer < ApplicationSerializer
  attributes :protected_system_fields, :triggers
  has_many :badges, serializer: AdminBadgeSerializer
  has_many :badge_groupings
  has_many :badge_types

  def protected_system_fields
    object.protected_system_fields
  end

  def triggers
    object.triggers
  end
end
