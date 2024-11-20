# frozen_string_literal: true

class UserBadge < ActiveRecord::Base
  self.ignored_columns = [
    :old_notification_id, # TODO: Remove once 20240829140226_drop_old_notification_id_columns has been promoted to pre-deploy
  ]

  belongs_to :badge
  belongs_to :user
  belongs_to :granted_by, class_name: "User"
  belongs_to :notification, dependent: :destroy
  belongs_to :post

  BOOLEAN_ATTRIBUTES = %w[is_favorite]

  scope :grouped_with_count,
        -> do
          group(:badge_id, :user_id)
            .select_for_grouping
            .order("MAX(featured_rank) ASC")
            .includes(:user, :granted_by, { badge: :badge_type }, post: :topic)
        end

  scope :select_for_grouping,
        -> do
          select(
            UserBadge.attribute_names.map do |name|
              operation = BOOLEAN_ATTRIBUTES.include?(name) ? "BOOL_OR" : "MAX"
              "#{operation}(user_badges.#{name}) AS #{name}"
            end,
            'COUNT(*) AS "count"',
          )
        end

  scope :for_enabled_badges,
        -> { where("user_badges.badge_id IN (SELECT id FROM badges WHERE enabled)") }

  scope :by_post_and_user,
        ->(posts) do
          posts.reduce(UserBadge.none) do |scope, post|
            scope.or(UserBadge.where(user_id: post.user_id, post_id: post.id))
          end
        end
  scope :for_post_header_badges,
        ->(posts) do
          by_post_and_user(posts).where(
            "user_badges.badge_id IN (SELECT id FROM badges WHERE show_posts AND enabled AND listable AND post_header)",
          )
        end

  validates :badge_id, presence: true, uniqueness: { scope: :user_id }, if: :single_grant_badge?

  validates :user_id, presence: true
  validates :granted_at, presence: true
  validates :granted_by, presence: true

  after_create do
    Badge.increment_counter "grant_count", self.badge_id
    UserStat.update_distinct_badge_count self.user_id
    UserBadge.update_featured_ranks! self.user_id
    self.trigger_user_badge_granted_event
  end

  after_destroy do
    Badge.decrement_counter "grant_count", self.badge_id
    UserStat.update_distinct_badge_count self.user_id
    UserBadge.update_featured_ranks! self.user_id

    DiscourseEvent.trigger(:user_badge_removed, self.badge_id, self.user_id)
    DiscourseEvent.trigger(:user_badge_revoked, user_badge: self)
  end

  def self.ensure_consistency!
    self.update_featured_ranks!
  end

  def self.update_featured_ranks!(user_id = nil)
    query = <<~SQL
      WITH featured_tl_badge AS -- Find the best trust level badge for each user
      (
        SELECT user_id, max(badge_id) as badge_id
        FROM user_badges
        WHERE badge_id IN (1,2,3,4)
        #{"AND user_id = #{user_id.to_i}" if user_id}
        GROUP BY user_id
      ),
      ranks AS ( -- Take all user badges, group by user_id and badge_id, and calculate a rank for each one
        SELECT
          user_badges.user_id,
          user_badges.badge_id,
          RANK() OVER (
            PARTITION BY user_badges.user_id -- Do a separate rank for each user
            ORDER BY BOOL_OR(badges.enabled) DESC, -- Disabled badges last
                    MAX(featured_tl_badge.user_id) NULLS LAST, -- Best tl badge first
                    BOOL_OR(user_badges.is_favorite) DESC NULLS LAST, -- Favorite badges next
                    CASE WHEN user_badges.badge_id IN (1,2,3,4) THEN 1 ELSE 0 END ASC, -- Non-featured tl badges last
                    MAX(badges.badge_type_id) ASC,
                    MAX(badges.grant_count) ASC,
                    user_badges.badge_id DESC
          ) rank_number
        FROM user_badges
        INNER JOIN badges ON badges.id = user_badges.badge_id
        LEFT JOIN featured_tl_badge ON featured_tl_badge.user_id = user_badges.user_id AND featured_tl_badge.badge_id = user_badges.badge_id
        #{"WHERE user_badges.user_id = #{user_id.to_i}" if user_id}
        GROUP BY user_badges.user_id, user_badges.badge_id
      )
      -- Now use that data to update the featured_rank column
      UPDATE user_badges SET featured_rank = rank_number
      FROM ranks WHERE ranks.badge_id = user_badges.badge_id AND ranks.user_id = user_badges.user_id AND featured_rank IS DISTINCT FROM rank_number
    SQL

    DB.exec query
  end

  def self.trigger_user_badge_granted_event(badge_id, user_id)
    DiscourseEvent.trigger(:user_badge_granted, badge_id, user_id)
  end

  private

  def trigger_user_badge_granted_event
    self.class.trigger_user_badge_granted_event(self.badge_id, self.user_id)
  end

  def single_grant_badge?
    self.badge ? self.badge.single_grant? : true
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
#  seq             :integer          default(0), not null
#  featured_rank   :integer
#  created_at      :datetime         not null
#  is_favorite     :boolean
#  notification_id :bigint
#
# Indexes
#
#  index_user_badges_on_badge_id_and_user_id              (badge_id,user_id)
#  index_user_badges_on_badge_id_and_user_id_and_post_id  (badge_id,user_id,post_id) UNIQUE WHERE (post_id IS NOT NULL)
#  index_user_badges_on_badge_id_and_user_id_and_seq      (badge_id,user_id,seq) UNIQUE WHERE (post_id IS NULL)
#  index_user_badges_on_user_id                           (user_id)
#
