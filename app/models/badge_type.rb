class BadgeType < ActiveRecord::Base
  Gold = 1
  Silver = 2
  Bronze = 3


  has_many :badges
  validates :name, presence: true, uniqueness: true
end

# == Schema Information
#
# Table name: badge_types
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_badge_types_on_name  (name) UNIQUE
#
