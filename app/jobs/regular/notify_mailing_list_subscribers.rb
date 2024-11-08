# frozen_string_literal: true

module Jobs
  class NotifyMailingListSubscribers < ::Jobs::Base
    include Skippable

    RETRY_TIMES = [
      5.minute,
      15.minute,
      30.minute,
      45.minute,
      90.minute,
      180.minute,
      300.minute,
    ].freeze

    sidekiq_options queue: "low"

    sidekiq_options retry: RETRY_TIMES.size

    sidekiq_retry_in do |count, exception|
      # returning nil/0 will trigger the default sidekiq
      # retry formula
      #
      # See https://github.com/mperham/sidekiq/blob/3330df0ee37cfd3e0cd3ef01e3e66b584b99d488/lib/sidekiq/job_retry.rb#L216-L234
      case exception.wrapped
      when SocketError
        return RETRY_TIMES[count]
      end
    end

    def execute(args)
      return if SiteSetting.disable_mailing_list_mode

      post_id = args[:post_id]
      post = post_id ? Post.with_deleted.find_by(id: post_id) : nil

      if !post || post.trashed? || post.user_deleted? || !post.topic || post.raw.blank? ||
           post.topic.private_message?
        return
      end

      users =
        User
          .activated
          .not_silenced
          .not_suspended
          .real
          .joins(:user_option)
          .where("user_options.mailing_list_mode AND user_options.mailing_list_mode_frequency > 0")
          .where(
            "NOT EXISTS (
                      SELECT 1
                      FROM muted_users mu
                      WHERE mu.muted_user_id = ? AND mu.user_id = users.id
                  )",
            post.user_id,
          )
          .where(
            "NOT EXISTS (
                      SELECT 1
                      FROM ignored_users iu
                      WHERE iu.ignored_user_id = ? AND iu.user_id = users.id
                  )",
            post.user_id,
          )
          .where(
            "NOT EXISTS (
                      SELECT 1
                      FROM topic_users tu
                      WHERE tu.topic_id = ? AND tu.user_id = users.id AND tu.notification_level = ?
                  )",
            post.topic_id,
            TopicUser.notification_levels[:muted],
          )
          .where(
            "NOT EXISTS (
                     SELECT 1
                     FROM category_users cu
                     WHERE cu.category_id = ? AND cu.user_id = users.id AND cu.notification_level = ?
                  )",
            post.topic.category_id,
            CategoryUser.notification_levels[:muted],
          )

      if SiteSetting.tagging_enabled?
        users =
          users.where(
            "NOT EXISTS (
           SELECT 1
           FROM tag_users tu
           WHERE tu.tag_id in (:tag_ids) AND tu.user_id = users.id AND tu.notification_level = :muted
        )",
            tag_ids: post.topic.tag_ids,
            muted: TagUser.notification_levels[:muted],
          )
      end

      users = users.where(approved: true) if SiteSetting.must_approve_users

      users = users.watching_topic(post.topic) if SiteSetting.mute_all_categories_by_default

      DiscourseEvent.trigger(:notify_mailing_list_subscribers, users, post)
      users.find_each do |user|
        if Guardian.new(user).can_see?(post)
          if EmailLog.reached_max_emails?(user)
            skip(user.email, user.id, post.id, SkippedEmailLog.reason_types[:exceeded_emails_limit])

            next
          end

          if user.user_stat.bounce_score >= SiteSetting.bounce_score_threshold
            skip(
              user.email,
              user.id,
              post.id,
              SkippedEmailLog.reason_types[:exceeded_bounces_limit],
            )

            next
          end

          if (user.id == post.user_id) && (user.user_option.mailing_list_mode_frequency == 2)
            skip(
              user.email,
              user.id,
              post.id,
              SkippedEmailLog.reason_types[:mailing_list_no_echo_mode],
            )

            next
          end

          begin
            if message = UserNotifications.mailing_list_notify(user, post)
              EmailLog.unique_email_per_post(post, user) do
                Email::Sender.new(message, :mailing_list, user).send
              end
            end
          rescue => e
            Discourse.handle_job_exception(
              e,
              error_context(
                args,
                "Sending post to mailing list subscribers",
                user_id: user.id,
                user_email: user.email,
              ),
            )
          end
        end
      end
    end

    def skip(to_address, user_id, post_id, reason_type)
      create_skipped_email_log(
        email_type: "mailing_list",
        to_address: to_address,
        user_id: user_id,
        post_id: post_id,
        reason_type: reason_type,
      )
    end
  end
end
