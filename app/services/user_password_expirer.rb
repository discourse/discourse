# frozen_string_literal: true

class UserPasswordExpirer
  class << self
    def expire_user_password(user)
      user.user_password&.update!(password_expired_at: Time.zone.now)
    end
  end
end
