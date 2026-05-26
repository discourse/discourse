# frozen_string_literal: true

class AdminLeaderboardSerializer < LeaderboardSerializer
  attributes :score_overrides, :scorable_category_ids
end
