class Badge < ActiveRecord::Base
  belongs_to :badge_type
  has_many :user_badges, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :badge_type, presence: true
  validates :allow_title, inclusion: [true, false]
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
#  allow_title   :boolean          default(FALSE), not null
#
# Indexes
#
#  index_badges_on_name  (name) UNIQUE
#
