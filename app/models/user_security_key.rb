# frozen_string_literal: true

class UserSecurityKey < ActiveRecord::Base
  belongs_to :user

  scope :second_factors, -> do
    where(factor_type: UserSecurityKey.factor_types[:second_factor], enabled: true)
  end

  def self.factor_types
    @factor_types ||= Enum.new(
      second_factor: 0,
      first_factor: 1,
      multi_factor: 2,
    )
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
#  name          :string           not null
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
