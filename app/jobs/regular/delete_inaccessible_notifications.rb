# frozen_string_literal: true

module Jobs
  class DeleteInaccessibleNotifications < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:topic_id) if args[:topic_id].blank?

      Notification
        .where(topic_id: args[:topic_id])
        .find_each do |notification|
          next unless notification.user && notification.topic

          notification.destroy if !Guardian.new(notification.user).can_see?(notification.topic)
        end
    end
  end
end
