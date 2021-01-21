# frozen_string_literal: true

class AdminBadgeSerializer < BadgeSerializer
  attributes :query, :trigger, :target_posts, :auto_revoke, :show_posts, :i18n_name

  def include_long_description?
    true
  end

  def include_i18n_name?
    object.system?
  end
end
