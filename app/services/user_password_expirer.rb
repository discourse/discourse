# frozen_string_literal: true

class UserPasswordExpirer
  def self.expire_user_password(user)
    UserPassword.create!(
      user:,
      password_hash: user.password_hash,
      password_salt: user.salt,
      password_algorithm: user.password_algorithm,
      password_expired_at: Time.zone.now,
    )
  end
end
