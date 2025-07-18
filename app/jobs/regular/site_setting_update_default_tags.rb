# frozen_string_literal: true

module Jobs
  class SiteSettingUpdateDefaultTags < ::Jobs::Base
    def execute(args)
      DistributedMutex.synchronize("process_site_setting_#{args[:id]}", validity: 10.minutes) do
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

        (new_tag_ids - previous_tag_ids).each do |tag_id|
          skip_user_ids = TagUser.where(tag_id: tag_id).pluck(:user_id)

          User
            .real
            .where(staged: false)
            .where.not(id: skip_user_ids)
            .select(:id)
            .find_in_batches(batch_size: batch_size) do |users|
              tag_users = []
              users.each do |user|
                tag_users << {
                  tag_id: tag_id,
                  user_id: user.id,
                  notification_level: notification_level,
                  created_at: now,
                  updated_at: now,
                }
              end
              TagUser.insert_all!(tag_users)
            end
          publish(id)
        end
      end
    end

    private

    def publish(site_setting_name)
      MessageBus.publish("#{site_setting_name}", status: "completed")
    end
  end
end
