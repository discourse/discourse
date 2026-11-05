# frozen_string_literal: true

module Jobs
  class UnassignNotification < ::Jobs::Base
    def execute(args)
      %i[topic_id assigned_to_id assigned_to_type assignment_id].each do |argument|
        raise Discourse::InvalidParameters.new(argument) if args[argument].nil?
      end

      assignment = Assignment.new(args.slice(:topic_id, :assigned_to_id, :assigned_to_type))
      assignment.assigned_users.each do |user|
        Assigner.publish_topic_tracking_state(assignment.topic, user.id) if assignment.topic
      end
      notifications =
        Notification.for_assignment(args[:assignment_id]).where(topic_id: args[:topic_id])
      notifications = notifications.where(user_id: args[:user_id]) if args[:user_id]
      notifications.find_each do |notification|
        replacement =
          if assignment.topic && notification.post_number == 1
            Assignment
              .active
              .where(topic_id: args[:topic_id], target_type: "Topic")
              .where.not(id: args[:assignment_id])
              .where.not(id: SilencedAssignment.select(:assignment_id))
              .includes(:assigned_to)
              .order(:id)
              .find { |candidate| candidate.assigned_users(user_id: notification.user_id).present? }
          end
        if replacement
          data = notification.data_hash
          data[:assignment_id] = replacement.id
          data[:message] = (
            if replacement.assigned_to_group?
              "discourse_assign.assign_group_notification"
            else
              "discourse_assign.assign_notification"
            end
          )
          data[:display_username] = (
            if replacement.assigned_to_group?
              replacement.assigned_to.name
            else
              replacement.assigned_by_user.username
            end
          )
          notification.update!(data: data.to_json)
        else
          notification.destroy!
        end
      end
    end
  end
end
