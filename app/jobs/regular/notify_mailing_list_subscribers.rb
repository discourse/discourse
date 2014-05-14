module Jobs

  class NotifyMailingListSubscribers < Jobs::Base

    def execute(args)
      post_id = args[:post_id]
      if post_id
        post = Post.with_deleted.find_by(id: post_id)
        # our topic can be deleted as well
        return if (post && post.trashed?) || !post.topic
      end

      raise Discourse::InvalidParameters.new(:post_id) unless post

      User.not_suspended
          .not_blocked
          .real
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
          .each do |user|
            if Guardian.new(user).can_see?(post)
              message = UserNotifications.mailing_list_notify(user, post)
              Email::Sender.new(message, :mailing_list, user).send
            end
      end

    end
  end
end
