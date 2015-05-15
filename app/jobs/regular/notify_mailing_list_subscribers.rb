module Jobs

  class NotifyMailingListSubscribers < Jobs::Base

    def execute(args)
      post_id = args[:post_id]
      post = post_id ? Post.with_deleted.find_by(id: post_id) : nil

      raise Discourse::InvalidParameters.new(:post_id) unless post
      return if post.trashed? || post.user_deleted? || (!post.topic)

      users =
          User.activated.not_blocked.not_suspended.real
          .where(mailing_list_mode:  true)
          .where('NOT EXISTS(
                      SELECT 1
                      FROM topic_users tu
                      WHERE
                        tu.topic_id = ? AND
                        tu.user_id = users.id AND
                        tu.notification_level = ?
                  )', post.topic_id, TopicUser.notification_levels[:muted])
          .where('NOT EXISTS(
                     SELECT 1
                     FROM category_users cu
                     WHERE
                       cu.category_id = ? AND
                       cu.user_id = users.id AND
                       cu.notification_level = ?
                  )', post.topic.category_id, CategoryUser.notification_levels[:muted])

      error_count = 0
      users.each do |user|
        if Guardian.new(user).can_see?(post)
          begin
            message = UserNotifications.mailing_list_notify(user, post)
            Email::Sender.new(message, :mailing_list, user).send
          rescue => e
            Discourse.handle_job_exception(e, error_context(
                args,
                "Sending post to mailing list subscribers", {
                user_id: user.id,
                user_email: user.email
            }))
            if (++error_count) >= 4
              raise RuntimeError, "ABORTING NotifyMailingListSubscribers due to repeated failures"
            end
          end
        end
      end

    end
  end
end
