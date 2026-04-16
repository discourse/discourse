# frozen_string_literal: true

class GroupUser < ActiveRecord::Base
  belongs_to :group
  belongs_to :user

  before_create :set_notification_level

  after_commit :sync_add_via_manager, on: :create
  after_commit :sync_remove_via_manager, on: :destroy

  def self.notification_levels
    NotificationLevels.all
  end

  def self.ensure_consistency!(last_seen = 1.hour.ago)
    update_first_unread_pm(last_seen)
  end

  def self.update_first_unread_pm(last_seen, limit: 10_000)
    DB.exec(
      <<~SQL,
    UPDATE group_users gu
    SET first_unread_pm_at = Y.min_date
    FROM (
      SELECT
        X.group_id,
        X.user_id,
        X.min_date
      FROM (
        SELECT
          gu.group_id,
          gu.user_id,
          COALESCE(Z.min_date, :now) min_date
        FROM group_users gu
        LEFT JOIN (
          SELECT
            gu2.group_id,
            gu2.user_id,
            MIN(t.updated_at) min_date
          FROM group_users gu2
          INNER JOIN topic_allowed_groups tag ON tag.group_id = gu2.group_id
          INNER JOIN topics t ON t.id = tag.topic_id
          INNER JOIN users u ON u.id = gu2.user_id
          LEFT JOIN topic_users tu ON t.id = tu.topic_id AND tu.user_id = gu2.user_id
          WHERE t.deleted_at IS NULL
          AND t.archetype = :archetype
          AND tu.last_read_post_number < CASE
                                         WHEN u.admin OR u.moderator #{SiteSetting.whispers_allowed_groups_map.any? ? "OR gu2.group_id IN (:whisperers_group_ids)" : ""}
                                         THEN t.highest_staff_post_number
                                         ELSE t.highest_post_number
                                         END
          AND (COALESCE(tu.notification_level, 1) >= 2)
          GROUP BY gu2.user_id, gu2.group_id
        ) AS Z ON Z.user_id = gu.user_id AND Z.group_id = gu.group_id
      ) AS X
      WHERE X.user_id IN (
        SELECT id
        FROM users
        WHERE last_seen_at IS NOT NULL
        AND last_seen_at > :last_seen
        ORDER BY last_seen_at DESC
        LIMIT :limit
      )
    ) Y
    WHERE gu.user_id = Y.user_id AND gu.group_id = Y.group_id
    SQL
      archetype: Archetype.private_message,
      last_seen: last_seen,
      limit: limit,
      now: 10.minutes.ago,
      whisperers_group_ids: SiteSetting.whispers_allowed_groups_map,
    )
  end

  protected

  def set_notification_level
    self.notification_level = group&.default_notification_level || 3
  end

  def self.set_category_notifications(group, user)
    bulk_set_category_notifications(group, [user.id])
  end

  def self.set_tag_notifications(group, user)
    bulk_set_tag_notifications(group, [user.id])
  end

  def self.bulk_set_category_notifications(group, user_ids)
    defaults = group.group_category_notification_defaults.to_a
    return if defaults.empty?

    defaults.each do |default|
      DB.exec(
        <<~SQL,
          INSERT INTO category_users (user_id, category_id, notification_level)
          SELECT unnest(ARRAY[:user_ids]::int[]), :category_id, :notification_level
          ON CONFLICT (user_id, category_id) DO UPDATE
            SET notification_level = #{semantically_higher_notification_level_sql("EXCLUDED.notification_level", "category_users.notification_level")}
        SQL
        user_ids: user_ids,
        category_id: default.category_id,
        notification_level: default.notification_level,
      )
    end

    CategoryUser.auto_watch(user_ids: user_ids)
    CategoryUser.auto_track(user_ids: user_ids)
  end

  def self.bulk_set_tag_notifications(group, user_ids)
    defaults = group.group_tag_notification_defaults.to_a
    return if defaults.empty?

    defaults.each do |default|
      DB.exec(
        <<~SQL,
          INSERT INTO tag_users (user_id, tag_id, notification_level, created_at, updated_at)
          SELECT unnest(ARRAY[:user_ids]::int[]), :tag_id, :notification_level, NOW(), NOW()
          ON CONFLICT (user_id, tag_id) DO UPDATE
            SET notification_level = #{semantically_higher_notification_level_sql("EXCLUDED.notification_level", "tag_users.notification_level")},
                updated_at = NOW()
        SQL
        user_ids: user_ids,
        tag_id: default.tag_id,
        notification_level: default.notification_level,
      )
    end

    TagUser.auto_watch(user_ids: user_ids)
    TagUser.auto_track(user_ids: user_ids)
  end

  def sync_add_via_manager
    GroupManager.new(group).sync_add_side_effects([user.id])
  end

  def sync_remove_via_manager
    GroupManager.new(group).sync_removal_side_effects([user.id])
  end

  def self.semantically_higher_notification_level_sql(new_col, existing_col)
    <<~SQL.squish
      CASE
        WHEN (CASE #{new_col} WHEN 3 THEN 5 ELSE #{new_col} END) >=
             (CASE #{existing_col} WHEN 3 THEN 5 ELSE #{existing_col} END)
        THEN #{new_col}
        ELSE #{existing_col}
      END
    SQL
  end
  private_class_method :semantically_higher_notification_level_sql
end

# == Schema Information
#
# Table name: group_users
#
#  id                 :integer          not null, primary key
#  group_id           :integer          not null
#  user_id            :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  owner              :boolean          default(FALSE), not null
#  notification_level :integer          default(2), not null
#  first_unread_pm_at :datetime         not null
#
# Indexes
#
#  index_group_users_on_group_id_and_user_id  (group_id,user_id) UNIQUE
#  index_group_users_on_user_id_and_group_id  (user_id,group_id) UNIQUE
#
