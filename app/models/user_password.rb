# frozen_string_literal: true

class UserPassword < ActiveRecord::Base
  TARGET_PASSWORD_ALGORITHM =
    "$pbkdf2-#{Rails.configuration.pbkdf2_algorithm}$i=#{Rails.configuration.pbkdf2_iterations},l=32$"
  PASSWORD_SALT_LENGTH = 16
  MAX_PASSWORD_LENGTH = 200

  attr_reader :password # required to build an instance of this model with password attribute without backing column
  attr_accessor :salt # TODO: Deprecate once we drop User.salt, this is only for passing through the randomized salt from User

  belongs_to :user, required: true # different from user_id, we need to allow for blank user_id at the point of validation since a newly built user needs to be saved before user_id is generated

  validates :user_id,
            uniqueness: {
              scope: :password_expired_at,
            },
            if: -> { password_expired_at.nil? }
  validates :password_hash, presence: true, length: { is: 64 }, uniqueness: { scope: :user_id }
  validates :password_salt, presence: true, length: { is: 32 }
  validates :password_algorithm, presence: true, length: { maximum: 64 }

  validate :password_validator
  before_save :ensure_password_is_hashed

  def password=(pw)
    return if pw.blank?
    @password = pw
    # ensure password is hashed before validations, this should not be in a before_validation hook as that's skipped during .save(validate: false) (e.g. Seedfu)
    self.password_salt = @salt || SecureRandom.hex(PASSWORD_SALT_LENGTH)
    self.password_algorithm = TARGET_PASSWORD_ALGORITHM
    self.password_hash = hash_password(password, password_salt, password_algorithm)
  end

  def password_validation_required?
    # password_required? || password.present?
    password.present?
  end

  def confirm_password?(pw)
    # nothing to confirm if this record has not been persisted yet
    return false if !persisted?

    # check latest persisted password_hash against passed-in password
    if (password_hash_was || password_hash) != hash_password(pw, password_salt, password_algorithm)
      return false
    end

    return true if password_algorithm == TARGET_PASSWORD_ALGORITHM

    # Regenerate password_hash with new algorithm and persist, we skip validation here since it has already run once when the hash was persisted the first time
    salt = SecureRandom.hex(PASSWORD_SALT_LENGTH)
    update_columns(
      password_algorithm: TARGET_PASSWORD_ALGORITHM,
      password_salt: salt,
      password_hash: hash_password(pw, salt, TARGET_PASSWORD_ALGORITHM),
    )
  end

  private

  def ensure_password_is_hashed
    if password
      # TODO: deprecate @salt once User.salt is dropped
      self.password_salt = @salt || SecureRandom.hex(PASSWORD_SALT_LENGTH)
      self.password_algorithm = TARGET_PASSWORD_ALGORITHM
      self.password_hash = hash_password(password, password_salt, password_algorithm)
    end
  end

  def password_validator
    UserPasswordValidator.new(attributes: :password).validate_each(self, :password, password)
  end

  def hash_password(password, salt, algorithm)
    raise StandardError.new("password is too long") if password.size > MAX_PASSWORD_LENGTH
    PasswordHasher.hash_password(password: password, salt: salt, algorithm: algorithm)
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
#  idx_user_passwords_on_user_id_and_expired_at_and_hash  (user_id,password_expired_at,password_hash)
#  index_user_passwords_on_user_id                        (user_id) UNIQUE WHERE (password_expired_at IS NULL)
#  index_user_passwords_on_user_id_and_password_hash      (user_id,password_hash) UNIQUE
#
