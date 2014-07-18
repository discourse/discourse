class BadgeGrouping < ActiveRecord::Base

  GettingStarted = 1
  Community = 2
  Posting = 3
  TrustLevel = 4
  Other = 5

  has_many :badges
end

# == Schema Information
#
# Table name: badge_groupings
#
#  id          :integer          not null, primary key
#  name        :string(255)      not null
#  description :string(255)      not null
#  position    :integer          not null
#  created_at  :datetime
#  updated_at  :datetime
#
