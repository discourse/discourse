class UserBadge < ActiveRecord::Base
  belongs_to :badge
  belongs_to :user
  belongs_to :granted_by, class_name: 'User'

  validates :badge_id, presence: true, uniqueness: {scope: :user_id}, if: 'badge.single_grant?'
  validates :user_id, presence: true
  validates :granted_at, presence: true
  validates :granted_by, presence: true

  # This may be inefficient, but not very easy to optimize unless the data hash
  # is converted into a hstore.
  def notification
    @notification ||= self.user.notifications.where(notification_type: Notification.types[:granted_badge]).where("data LIKE ?", "%" + self.badge_id.to_s + "%").select {|n| n.data_hash["badge_id"] == self.badge_id }.first
  end
end

# == Schema Information
#
# Table name: user_badges
#
#  id            :integer          not null, primary key
#  badge_id      :integer          not null
#  user_id       :integer          not null
#  granted_at    :datetime         not null
#  granted_by_id :integer          not null
#
# Indexes
#
#  index_user_badges_on_badge_id_and_user_id  (badge_id,user_id)
#  index_user_badges_on_user_id               (user_id)
#
