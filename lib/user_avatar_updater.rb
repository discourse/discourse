# frozen_string_literal: true

class UserAvatarUpdater
  def self.update(guardian, user, upload, type: "custom")
    guardian.ensure_can_pick_avatar_source!(user, type)
    avatar = user.user_avatar || user.build_user_avatar
    guardian.ensure_can_pick_avatar!(avatar, upload)
    user.pick_avatar!(upload&.id, type: type.to_sym)
    SiteSetting.use_site_small_logo_as_system_avatar = false if user.is_system_user?
  end
end
