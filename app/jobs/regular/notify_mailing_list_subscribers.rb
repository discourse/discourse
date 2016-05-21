module Jobs

  class NotifyMailingListSubscribers < Jobs::Base

    sidekiq_options queue: 'low'

    def execute(args)
      return if SiteSetting.disable_mailing_list_mode

      post_id = args[:post_id]
      post = post_id ? Post.with_deleted.find_by(id: post_id) : nil

      raise Discourse::InvalidParameters.new(:post_id) unless post
      return if post.trashed? || post.user_deleted? || (!post.topic)

      users =
          User.activated.not_blocked.not_suspended.real
          .joins(:user_option)
          .where(user_options: {mailing_list_mode: true, mailing_list_mode_frequency: 1})
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

      users.each do |user|
        if Guardian.new(user).can_see?(post)
          begin
            if EmailLog.reached_max_emails?(user)
              EmailLog.create!(
                email_type: 'mailing_list',
                to_address: user.email,
                user_id: user.id,
                post_id: post.id,
                skipped: true,
                skipped_reason: "[MailingList] #{I18n.t('email_log.exceeded_limit')}"
              )
            else
              message = UserNotifications.mailing_list_notify(user, post)
              if message
                EmailLog.unique_email_per_post(post, user) do
                  Email::Sender.new(message, :mailing_list, user).send
                end
              end
            end
          rescue => e
            Discourse.handle_job_exception(e, error_context(args, "Sending post to mailing list subscribers", { user_id: user.id, user_email: user.email }))
          end
        end
      end

    end
  end
end
