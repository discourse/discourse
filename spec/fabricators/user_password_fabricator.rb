# frozen_string_literal: true

Fabricator(:user_password) do
  transient password: "myawesomefakepassword"

  user { Fabricate(:user) }
  salt { SecureRandom.hex(User::PASSWORD_SALT_LENGTH) }
  algorithm { User::TARGET_PASSWORD_ALGORITHM }

  after_build do |user_password, transients|
    user_password.hash =
      PasswordHasher.hash_password(
        password: transients[:password],
        salt: user_password.salt,
        algorithm: user_password.algorithm,
      )
  end
end

Fabricator(:expired_user_password, from: :user_password) { expired_at { 1.day.ago } }
