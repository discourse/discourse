class BadgeGrouping < ActiveRecord::Base

  GettingStarted = 1
  Community = 2
  Posting = 3
  TrustLevel = 4
  Other = 5

  has_many :badges

  def system?
    id && id <= 5
  end

  def default_position=(pos)
    self.position ||= pos
  end
end

# == Schema Information
#
# Table name: badge_groupings
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  description :text
#  position    :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
