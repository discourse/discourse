class UserBadge < ActiveRecord::Base
  belongs_to :badge
  belongs_to :user
  belongs_to :granted_by, class_name: 'User'
  belongs_to :notification, dependent: :destroy
  belongs_to :post

  validates :badge_id, presence: true, uniqueness: {scope: :user_id}, if: 'badge.single_grant?'
  validates :user_id, presence: true
  validates :granted_at, presence: true
  validates :granted_by, presence: true

  after_create do
    Badge.increment_counter 'grant_count', self.badge_id
  end

  after_destroy do
    Badge.decrement_counter 'grant_count', self.badge_id
  end


  # Make sure we don't have duplicate badges.
  def self.ensure_consistency!
    dup_ids = exec_sql("SELECT u1.id
                        FROM user_badges u1, user_badges u2, badges
                        WHERE u1.badge_id = badges.id
                          AND u1.user_id = u2.user_id
                          AND u1.badge_id = u2.badge_id
                          AND (NOT badges.multiple_grant)
                          AND u1.granted_at > u2.granted_at
                        LIMIT 1000").to_a

   dup_ids << exec_sql("SELECT u1.id
                          FROM user_badges u1, user_badges u2, badges
                          WHERE u1.badge_id = badges.id
                            AND u1.user_id = u2.user_id
                            AND u1.badge_id = u2.badge_id
                            AND badges.multiple_grant
                            AND u1.post_id = u2.post_id
                            AND u1.granted_at > u2.granted_at
                        LIMIT 1000").to_a

    dup_ids.flatten!
    dup_ids.map! {|row| row['id'].to_i }
    dup_ids.uniq!
    UserBadge.where(id: dup_ids).destroy_all
  end
end

# == Schema Information
#
# Table name: user_badges
#
#  id              :integer          not null, primary key
#  badge_id        :integer          not null
#  user_id         :integer          not null
#  granted_at      :datetime         not null
#  granted_by_id   :integer          not null
#  post_id         :integer
#  notification_id :integer
#
# Indexes
#
#  index_user_badges_on_badge_id_and_user_id              (badge_id,user_id)
#  index_user_badges_on_badge_id_and_user_id_and_post_id  (badge_id,user_id,post_id) UNIQUE
#
