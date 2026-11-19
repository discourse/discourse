# frozen_string_literal: true

class AdminLeaderboardSerializer < LeaderboardSerializer
  attributes :score_overrides, :scorable_category_ids, :created_by

  def created_by
    return if object.created_by.blank?
    BasicUserSerializer.new(object.created_by, root: false).as_json
  end
end
