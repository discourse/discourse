# frozen_string_literal: true

module Jobs
  class NotifyMovedPosts < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:post_ids) if args[:post_ids].blank?
      raise Discourse::InvalidParameters.new(:moved_by_id) if args[:moved_by_id].blank?

      posts =
        Post
          .includes(:user, :topic)
          .where(id: args[:post_ids])
          .where("user_id <> ?", args[:moved_by_id])
          .order(post_number: :asc)
      return if posts.blank?

      moved_by = User.find_by(id: args[:moved_by_id])

      # Make sure we don't notify the same user twice (in case multiple posts were moved at once.)
      users_notified = Set.new
      posts.each do |p|
        next if users_notified.include?(p.user_id)

        p.user.notifications.create(
          notification_type: Notification.types[:moved_post],
          topic_id: p.topic_id,
          post_number: p.post_number,
          data: { topic_title: p.topic.title, display_username: moved_by.username }.to_json,
        )
        users_notified << p.user_id
      end
    end
  end
end
