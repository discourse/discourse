class UserSecondFactor < ActiveRecord::Base
  belongs_to :user
  scope :backup_codes, -> { where(method: 2, enabled: true) }

  def self.methods
    @methods ||= Enum.new(
      totp: 1,
      backup_codes: 2,
    )
  end

  def self.totp
    where(method: 1).first
  end

end

# == Schema Information
#
# Table name: user_second_factors
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  method     :integer          not null
#  data       :string           not null
#  enabled    :boolean          default(FALSE), not null
#  last_used  :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
