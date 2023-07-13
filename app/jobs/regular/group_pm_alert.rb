# frozen_string_literal: true

module Jobs
  class GroupPmAlert < ::Jobs::Base
    def execute(args)
      return unless user = User.find_by(id: args[:user_id])
      return unless group = Group.find_by(id: args[:group_id])
      return unless post = Post.find_by(id: args[:post_id])
      return unless topic = post.topic

      group.set_message_default_notification_levels!(topic, ignore_existing: true)

      alerter = PostAlerter.new

      group
        .users
        .where("group_users.notification_level = :level", level: NotificationLevels.all[:tracking])
        .find_each { |u| alerter.notify_group_summary(u, topic) }

      notification_data = {
        notification_type: Notification.types[:invited_to_private_message],
        topic_id: topic.id,
        post_number: 1,
        data: {
          topic_title: topic.title,
          display_username: user.username,
          group_id: group.id,
        }.to_json,
      }

      group
        .users
        .where(
          "group_users.notification_level in (:levels) AND user_id != :id",
          levels: [NotificationLevels.all[:watching], NotificationLevels.all[:watching_first_post]],
          id: user.id,
        )
        .find_each { |u| u.notifications.create!(notification_data) }
    end
  end
end
