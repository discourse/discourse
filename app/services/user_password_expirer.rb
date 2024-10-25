# frozen_string_literal: true

class UserPasswordExpirer
  def self.expire_user_password(user)
    user.user_password&.update!(password_expired_at: Time.zone.now)
  end
end
