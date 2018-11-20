class UserSecondFactor < ActiveRecord::Base
  belongs_to :user

  scope :backup_codes, -> do
    where(method: UserSecondFactor.methods[:backup_codes], enabled: true)
  end

  def self.methods
    @methods ||= Enum.new(
      totp: 1,
      backup_codes: 2,
    )
  end

  def self.totp
    where(method: self.methods[:totp]).first
  end

end

# == Schema Information
#
# Table name: user_second_factors
#
#  id         :bigint(8)        not null, primary key
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
#  index_user_second_factors_on_user_id  (user_id)
#
