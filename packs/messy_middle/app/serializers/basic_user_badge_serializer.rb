# frozen_string_literal: true

class BasicUserBadgeSerializer < ApplicationSerializer
  attributes :id, :granted_at, :count, :grouping_position

  has_one :badge

  def include_count?
    object.respond_to? :count
  end

  def grouping_position
    object.badge&.badge_grouping&.position
  end
end
