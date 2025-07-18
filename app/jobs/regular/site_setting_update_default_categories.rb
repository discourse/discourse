# frozen_string_literal: true

module Jobs
  class SiteSettingUpdateDefaultCategories < ::Jobs::Base
    def execute(args)
      DistributedMutex.synchronize("process_site_setting_#{args[:id]}", validity: 10.minutes) do
        id = args[:id]
        value = args[:value]
        new_value = value.nil? ? "" : value
        previous_value = args[:previous_value]

        batch_size = 50_000
        previous_category_ids = previous_value.split("|")
        new_category_ids = new_value.split("|")
        offset = offset.to_i

        notification_level = SiteSettingUpdateExistingUsers.category_notification_level(id)

        categories_to_unwatch = previous_category_ids - new_category_ids

        CategoryUser
          .where(category_id: categories_to_unwatch, notification_level: notification_level)
          .in_batches(of: batch_size) { |batch| batch.delete_all }

        TopicUser
          .joins(:topic)
          .where(
            notification_level: TopicUser.notification_levels[:watching],
            notifications_reason_id: TopicUser.notification_reasons[:auto_watch_category],
            topics: {
              category_id: categories_to_unwatch,
            },
          )
          .select("topic_users.id")
          .in_batches(of: batch_size) do |batch|
            batch.update_all(notification_level: TopicUser.notification_levels[:regular])
          end

        (new_category_ids - previous_category_ids).each do |category_id|
          skip_user_ids = CategoryUser.where(category_id: category_id).pluck(:user_id)
          User
            .real
            .where(staged: false)
            .where.not(id: skip_user_ids)
            .select(:id)
            .find_in_batches(batch_size: batch_size) do |users|
              category_users = []
              users.each do |user|
                category_users << {
                  category_id: category_id,
                  user_id: user.id,
                  notification_level: notification_level,
                }
              end
              CategoryUser.insert_all!(category_users)
            end
        end

        publish(id)
      end
    end

    private

    def publish(site_setting_name)
      MessageBus.publish("#{site_setting_name}", status: "completed")
    end
  end
end
