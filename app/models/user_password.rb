# frozen_string_literal: true

class UserPassword < ActiveRecord::Base
  MAX_PASSWORD_LENGTH = 200
  TARGET_PASSWORD_ALGORITHM =
    "$pbkdf2-#{Rails.configuration.pbkdf2_algorithm}$i=#{Rails.configuration.pbkdf2_iterations},l=32$".freeze
  PASSWORD_SALT_LENGTH = 16

  belongs_to :user, required: true

  validates :user_id, uniqueness: true
  validate :password_validator
  before_save :ensure_password_is_hashed
  after_save :clear_raw_password

  def password
    # this getter method is still required, but we store the set password in @raw_password instead of making it easily accessible from the getter
    nil
  end

  def password=(pw)
    return if pw.blank?

    self.password_hash_will_change!
    @raw_password = pw
  end

  def password_validation_required?
    @raw_password.present?
  end

  def confirm_password?(pw)
    # nothing to confirm if this record has not been persisted yet
    return false if !persisted?
    return false if password_hash != hash_password(pw, password_salt, password_algorithm)
    regen_password!(pw) if password_algorithm != TARGET_PASSWORD_ALGORITHM

    true
  end

  private

  def clear_raw_password
    @raw_password = nil
  end

  def password_validator
    UserPasswordValidator.new(attributes: :password).validate_each(self, :password, @raw_password)
  end

  def hash_password(pw, salt, algorithm)
    raise StandardError.new("password is too long") if pw.size > MAX_PASSWORD_LENGTH
    PasswordHasher.hash_password(password: pw, salt: salt, algorithm: algorithm)
  end

  def ensure_password_is_hashed
    return if @raw_password.blank?

    self.password_salt = SecureRandom.hex(PASSWORD_SALT_LENGTH)
    self.password_algorithm = TARGET_PASSWORD_ALGORITHM
    self.password_hash = hash_password(@raw_password, password_salt, password_algorithm)
    self.password_expired_at = nil
  end

  def regen_password!(pw)
    # Regenerate password_hash with new algorithm and persist, we skip validation here since it has already run once when the hash was persisted the first time
    salt = SecureRandom.hex(PASSWORD_SALT_LENGTH)
    update_columns(
      password_algorithm: TARGET_PASSWORD_ALGORITHM,
      password_salt: salt,
      password_hash: hash_password(pw, salt, TARGET_PASSWORD_ALGORITHM),
    )
  end
end

# == Schema Information
#
# Table name: user_passwords
#
#  id                  :integer          not null, primary key
#  user_id             :integer          not null
#  password_hash       :string(64)       not null
#  password_salt       :string(32)       not null
#  password_algorithm  :string(64)       not null
#  password_expired_at :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_user_passwords_on_user_id  (user_id) UNIQUE
#
