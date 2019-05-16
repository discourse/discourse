# frozen_string_literal: true

class AdminBadgeSerializer < BadgeSerializer
  attributes :query, :trigger, :target_posts, :auto_revoke, :show_posts

  def include_long_description?
    true
  end
end
