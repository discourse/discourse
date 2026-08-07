# frozen_string_literal: true

class UserSecondFactor < ActiveRecord::Base
  include SecondFactorManager

  MAX_TOTPS_PER_USER = 50
  MAX_NAME_LENGTH = 300

  belongs_to :user

  scope :backup_codes, -> { where(method: UserSecondFactor.methods[:backup_codes], enabled: true) }

  scope :totps, -> { where(method: UserSecondFactor.methods[:totp], enabled: true) }

  scope :all_totps, -> { where(method: UserSecondFactor.methods[:totp]) }

  validates :name, length: { maximum: MAX_NAME_LENGTH }, if: :name_changed?

  validate :count_per_user_does_not_exceed_limit, on: :create

  # `passkey` is a virtual method: passkeys live in `user_security_keys`
  # (factor_type first_factor), never in this table. The enum value exists so
  # the `second_factor_method` wire param can distinguish the passkey WebAuthn
  # ceremony (user verification required) from the security key one.
  def self.methods
    @methods ||= Enum.new(totp: 1, backup_codes: 2, security_key: 3, passkey: 4)
  end

  def totp_object
    get_totp_object(data)
  end

  def totp_provisioning_uri
    totp_object.provisioning_uri(user.email)
  end

  private

  def count_per_user_does_not_exceed_limit
    if method == UserSecondFactor.methods[:totp]
      if self.class.where(method: method, user_id: user_id).count >= MAX_TOTPS_PER_USER
        errors.add(:base, I18n.t("login.too_many_authenticators"))
      end
    end
  end
end

# == Schema Information
#
# Table name: user_second_factors
#
#  id         :bigint           not null, primary key
#  data       :string           not null
#  enabled    :boolean          default(FALSE), not null
#  last_used  :datetime
#  method     :integer          not null
#  name       :string(300)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_user_second_factors_on_method_and_enabled  (method,enabled)
#  index_user_second_factors_on_user_id             (user_id)
#
