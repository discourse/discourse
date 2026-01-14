# frozen_string_literal: true

module Jobs
  class UnassignNotification < ::Jobs::Base
    def execute(args)
      %i[topic_id assigned_to_id assigned_to_type assignment_id].each do |argument|
        raise Discourse::InvalidParameters.new(argument) if args[argument].nil?
      end

      assignment = Assignment.new(args.slice(:topic_id, :assigned_to_id, :assigned_to_type))
      assignment.assigned_users.each do |user|
        Assigner.publish_topic_tracking_state(assignment.topic, user.id)
      end
      Notification
        .for_assignment(args[:assignment_id])
        .where(user: assignment.assigned_users, topic: assignment.topic)
        .destroy_all
    end
  end
end
