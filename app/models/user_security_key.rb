# frozen_string_literal: true

class UserSecurityKey < ActiveRecord::Base
  belongs_to :user
  MAX_KEYS_PER_USER = 50
  MAX_NAME_LENGTH = 300

  scope :second_factors,
        -> { where(factor_type: UserSecurityKey.factor_types[:second_factor], enabled: true) }

  validates :name, length: { maximum: MAX_NAME_LENGTH }, if: :name_changed?
  validate :count_per_user_does_not_exceed_limit, on: :create

  def self.factor_types
    @factor_types ||= Enum.new(second_factor: 0, first_factor: 1, multi_factor: 2)
  end

  private

  def count_per_user_does_not_exceed_limit
    if UserSecurityKey.where(user_id: self.user_id).count >= MAX_KEYS_PER_USER
      errors.add(:base, I18n.t("login.too_many_security_keys"))
    end
  end
end

# == Schema Information
#
# Table name: user_security_keys
#
#  id            :bigint           not null, primary key
#  user_id       :bigint           not null
#  credential_id :string           not null
#  public_key    :string           not null
#  factor_type   :integer          default(0), not null
#  enabled       :boolean          default(TRUE), not null
#  name          :string(300)      not null
#  last_used     :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_user_security_keys_on_credential_id            (credential_id) UNIQUE
#  index_user_security_keys_on_factor_type              (factor_type)
#  index_user_security_keys_on_factor_type_and_enabled  (factor_type,enabled)
#  index_user_security_keys_on_last_used                (last_used)
#  index_user_security_keys_on_public_key               (public_key)
#  index_user_security_keys_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
