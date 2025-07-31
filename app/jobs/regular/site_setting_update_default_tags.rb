# frozen_string_literal: true

module Jobs
  class SiteSettingUpdateDefaultTags < ::Jobs::Base
    # There should only be one of these jobs running at a time
    cluster_concurrency 1

    def execute(args)
      id = args[:id]
      value = args[:value]
      new_value = value.nil? ? "" : value
      previous_value = args[:previous_value]

      batch_size = 50_000

      previous_tag_ids = Tag.where(name: previous_value.split("|")).pluck(:id)
      new_tag_ids = Tag.where(name: new_value.split("|")).pluck(:id)
      now = Time.zone.now

      notification_level = SiteSettingUpdateExistingUsers.tag_notification_level(id)

      TagUser
        .where(tag_id: (previous_tag_ids - new_tag_ids), notification_level: notification_level)
        .in_batches(of: batch_size) { |batch| batch.delete_all }

      modified_tags = new_tag_ids - previous_tag_ids

      skip_user_ids = {}
      users_scope = {}

      modified_tags.each do |tag_id|
        skip_user_ids[:tag_id] = TagUser.where(tag_id: tag_id).pluck(:user_id)
        users_scope[:tag_id] = User.real.where(staged: false).where.not(id: skip_user_ids[:tag_id])
      end

      total_users_to_process = users_scope.values.count.sum
      processed_total = 0

      modified_tags.each do |tag_id|
        skip_user_ids[:tag_id] = TagUser.where(tag_id: tag_id).pluck(:user_id)
        users_scope[:tag_id] = User.real.where(staged: false).where.not(id: skip_user_ids[:tag_id])

        users_scope[:tag_id]
          .select(:id)
          .find_in_batches(batch_size: batch_size) do |users|
            tag_users =
              users.map do |user|
                {
                  tag_id: tag_id,
                  user_id: user.id,
                  notification_level: notification_level,
                  created_at: now,
                  updated_at: now,
                }
              end

            TagUser.insert_all!(tag_users)

            processed_total += users.size
            publish(id, processed_total, total_users_to_process)
          end
      end

      publish(id)
    end

    private

    def publish(
      site_setting_name,
      processed_total = 0,
      total_users_to_process = 0,
      modified_categories = nil
    )
      status =
        if modified_categories.nil? || processed_total >= total_users_to_process
          "completed"
        else
          "enqueued"
        end

      MessageBus.publish(
        site_setting_name,
        status: status,
        progress: "#{processed_total}/#{total_users_to_process}",
        group_ids: [Group::AUTO_GROUPS[:admin]],
      )
    end
  end
end
