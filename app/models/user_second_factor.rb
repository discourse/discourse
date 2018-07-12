class UserSecondFactor < ActiveRecord::Base
  belongs_to :user

  scope :totp, -> do
    where(method: UserSecondFactor.methods[:totp])
  end

  scope :backup_codes, -> do
    where(method: UserSecondFactor.methods[:backup_codes], enabled: true)
  end

  def self.methods
    @methods ||= Enum.new(
      totp: 1,
      backup_codes: 2,
    )
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
