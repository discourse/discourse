class AdminBadgeSerializer < BadgeSerializer
  attributes :query, :trigger, :target_posts, :auto_revoke, :show_posts
end
