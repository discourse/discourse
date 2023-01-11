# frozen_string_literal: true

module Jobs
  class GroupPmUpdateSummary < ::Jobs::Base
    def execute(args)
      return unless group = Group.find_by(id: args[:group_id])
      return unless topic = Topic.find_by(id: args[:topic_id])

      group.set_message_default_notification_levels!(topic, ignore_existing: true)

      alerter = PostAlerter.new

      group
        .users
        .where("group_users.notification_level = :level", level: NotificationLevels.all[:tracking])
        .find_each do |u|
          alerter.notify_group_summary(u, topic, acting_user_id: args[:acting_user_id])
        end
    end
  end
end
