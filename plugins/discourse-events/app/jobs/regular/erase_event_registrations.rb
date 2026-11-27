# frozen_string_literal: true

module Jobs
  class EraseEventRegistrations < ::Jobs::Base
    sidekiq_options retry: 10

    def self.enqueue_for(user_id)
      DB.after_commit do
        Jobs.enqueue(:erase_event_registrations, user_id:)
      rescue StandardError => e
        # The account change has committed. The scheduled scan can rediscover it.
        Discourse.warn_exception(
          e,
          message: "Could not enqueue event registration erasure for user #{user_id}",
        )
      end
    end

    def execute(args)
      user_id = args.fetch(:user_id)
      if User.exists?(user_id)
        through =
          UserHistory.where(
            action: UserHistory.actions[:anonymize_user],
            target_user_id: user_id,
          ).maximum(:created_at)
        return unless through
      end
      DiscourseEvents::Events::EraseRegistrations.call(user_id, through:)
    end
  end
end
