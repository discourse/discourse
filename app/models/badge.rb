class Badge < ActiveRecord::Base
  belongs_to :badge_type

  validates :name, presence: true, uniqueness: true
  validates :badge_type, presence: true
end

# == Schema Information
#
# Table name: badges
#
#  id            :integer          not null, primary key
#  name          :string(255)      not null
#  description   :text
#  badge_type_id :integer          not null
#  grant_count   :integer          default(0), not null
#  created_at    :datetime
#  updated_at    :datetime
#
# Indexes
#
#  index_badges_on_badge_type_id  (badge_type_id)
#  index_badges_on_name           (name) UNIQUE
#
