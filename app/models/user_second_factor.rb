# frozen_string_literal: true

class UserSecondFactor < ActiveRecord::Base
  belongs_to :user

  scope :backup_codes, -> do
    where(method: UserSecondFactor.methods[:backup_codes], enabled: true)
  end

  scope :totps, -> do
    where(method: UserSecondFactor.methods[:totp], enabled: true)
  end

  scope :all_totps, -> do
    where(method: UserSecondFactor.methods[:totp])
  end

  def self.methods
    @methods ||= Enum.new(
      totp: 1,
      backup_codes: 2,
    )
  end

  def get_totp_object
    ROTP::TOTP.new(self.data, issuer: SiteSetting.title)
  end

  def totp_provisioning_uri
    get_totp_object.provisioning_uri(user.email)
  end

end

# == Schema Information
#
# Table name: user_second_factors
#
#  id         :bigint           not null, primary key
#  user_id    :integer          not null
#  method     :integer          not null
#  data       :string           not null
#  enabled    :boolean          default(FALSE), not null
#  last_used  :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_user_second_factors_on_method_and_enabled  (method,enabled)
#  index_user_second_factors_on_user_id             (user_id)
#
