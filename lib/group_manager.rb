# frozen_string_literal: true

class GroupManager
  def initialize(acting_user, group)
    @acting_user = acting_user
    @group = group
  end

  def add(user_ids, automatic: false)
    return [] if user_ids.blank?
    @group.bulk_add(user_ids, automatic:)
  end

  def remove(user_ids)
    return [] if user_ids.blank?
    @group.bulk_remove(user_ids)
  end

  def bulk_add(user_ids, automatic: false)
    return [] if user_ids.blank?

    added_user_ids = nil

    Group.transaction do
      sql = <<~SQL
      INSERT INTO group_users
        (group_id, user_id, notification_level, created_at, updated_at)
      SELECT
        :group_id,
        u.id,
        :notification_level,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM users AS u
      WHERE u.id IN (:user_ids)
      AND NOT EXISTS (
        SELECT 1 FROM group_users AS gu
        WHERE gu.user_id = u.id AND
        gu.group_id = :group_id
      )
      RETURNING user_id
      SQL

      added_user_ids =
        DB.query_single(
          sql,
          group_id: @group.id,
          user_ids: user_ids,
          notification_level: @group.default_notification_level,
        )

      return [] if added_user_ids.blank?

      if @group.primary_group?
        User
          .where(id: added_user_ids)
          .where("flair_group_id IS NOT DISTINCT FROM primary_group_id")
          .update_all(flair_group_id: @group.id)

        DB.exec(<<~SQL, user_ids: added_user_ids, new_title: @group.title)
            UPDATE users u
            SET title = :new_title
            WHERE u.id IN (:user_ids)
              AND u.primary_group_id IS NOT NULL
              AND EXISTS (
                SELECT 1 FROM groups g
                WHERE g.id = u.primary_group_id
                  AND g.title = u.title
              )
          SQL

        User.where(id: added_user_ids).update_all(primary_group_id: @group.id)
      end

      if @group.title.present?
        User.where(id: added_user_ids, title: [nil, ""]).update_all(title: @group.title)
      end

      Group.update_counters(@group.id, user_count: added_user_ids.size)
    end

    if @group.grant_trust_level.present? && !@group.grant_trust_level.zero?
      Jobs.enqueue(
        :bulk_grant_trust_level,
        user_ids: added_user_ids,
        trust_level: @group.grant_trust_level,
      )
    end

    GroupUser.bulk_set_category_notifications(@group, added_user_ids)
    GroupUser.bulk_set_tag_notifications(@group, added_user_ids)

    User
      .where(id: added_user_ids)
      .find_each { |user| @group.trigger_user_added_event(user, automatic) }

    bulk_publish_category_updates(added_user_ids)

    added_user_ids
  end

  def bulk_remove(user_ids)
    return [] if user_ids.blank?

    group_users_to_remove = @group.group_users.where(user_id: user_ids)
    return [] if group_users_to_remove.empty?

    removed_user_ids = group_users_to_remove.pluck(:user_id)

    webhook_payloads = build_user_removed_webhook_payloads(group_users_to_remove)

    Group.transaction do
      @group.group_users.where(user_id: removed_user_ids).delete_all

      User.where(primary_group_id: @group.id, id: removed_user_ids).update_all(
        primary_group_id: nil,
      )
      User.where(flair_group_id: @group.id, id: removed_user_ids).update_all(flair_group_id: nil)

      if @group.title.present?
        DB.exec(<<~SQL, user_ids: removed_user_ids, title: @group.title)
            UPDATE users u
            SET title = NULL
            WHERE u.id IN (:user_ids)
              AND u.title = :title
              AND NOT EXISTS (
                SELECT 1 FROM group_users gu
                JOIN groups g ON g.id = gu.group_id
                WHERE gu.user_id = u.id
                  AND g.title IS NOT NULL AND g.title <> ''
              )
              AND NOT EXISTS (
                SELECT 1 FROM user_badges ub
                JOIN badges b ON b.id = ub.badge_id
                WHERE ub.user_id = u.id
                  AND b.allow_title = true
              )
          SQL

        User
          .where(id: removed_user_ids, title: @group.title)
          .find_each { |user| user.update_column(:title, user.next_best_title) }
      end

      Group.update_counters(@group.id, user_count: -removed_user_ids.size)
    end

    if @group.grant_trust_level.present? && !@group.grant_trust_level.zero?
      Jobs.enqueue(:bulk_grant_trust_level, user_ids: removed_user_ids, recalculate: true)
    end

    bulk_publish_category_updates(removed_user_ids)

    User.where(id: removed_user_ids).find_each { |user| @group.trigger_user_removed_event(user) }
    enqueue_user_removed_webhook_events(webhook_payloads)

    removed_user_ids
  end

  private

  def publish_category_updates(user)
    if @group.categories.count < Group::PUBLISH_CATEGORIES_LIMIT
      guardian = Guardian.new(user)
      group_categories = @group.categories.map { |c| Category.set_permission!(guardian, c) }
      updated_categories = group_categories.select(&:permission)
      removed_category_ids = group_categories.reject(&:permission).map(&:id)

      MessageBus.publish(
        "/categories",
        {
          categories: ActiveModel::ArraySerializer.new(updated_categories).as_json,
          deleted_categories: removed_category_ids,
        },
        user_ids: [user.id],
      )
    else
      Discourse.request_refresh!(user_ids: [user.id])
    end
  end

  def bulk_publish_category_updates(user_ids)
    return if user_ids.blank?
    return unless @group.categories.exists?

    if user_ids.size == 1
      user = User.find(user_ids.first)
      publish_category_updates(user)
    else
      Discourse.request_refresh!(user_ids:)
    end
  end

  def build_user_removed_webhook_payloads(group_users_relation)
    return unless WebHook.active_web_hooks(:group_user)

    payloads = []
    group_users_relation.find_each do |group_user|
      payloads << {
        id: group_user.id,
        payload: WebHook.generate_payload(:group_user, group_user, WebHookGroupUserSerializer),
      }
    end
    payloads
  end

  def enqueue_user_removed_webhook_events(webhook_payloads)
    webhook_payloads&.each do |webhook_payload|
      WebHook.enqueue_hooks(
        :group_user,
        :user_removed_from_group,
        id: webhook_payload[:id],
        payload: webhook_payload[:payload],
        group_ids: [@group.id],
      )
    end
  end
end
