# frozen_string_literal: true

class AdminBadgeSerializer < BadgeSerializer
  root 'admin_badge'
  attributes :query, :trigger, :target_posts, :auto_revoke, :show_posts

  def include_long_description?
    true
  end
end
