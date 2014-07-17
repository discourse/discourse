class BadgeGrouping < ActiveRecord::Base

  module Position
    GettingStarted = 10
    Community = 11
    Posting = 12
    TrustLevel = 13
    Other = 14
  end

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
