# frozen_string_literal: true

class GroupUserSerializer < BasicUserSerializer
  include UserPrimaryGroupMixin

  attributes :name, :title, :last_posted_at, :last_seen_at, :added_at, :timezone, :status

  def timezone
    user.user_option.timezone
  end

  def include_added_at?
    object.respond_to? :added_at
  end

  def include_status?
    SiteSetting.enable_user_status && user.has_status?
  end

  def status
    UserStatusSerializer.new(user.user_status, root: false)
  end
end
