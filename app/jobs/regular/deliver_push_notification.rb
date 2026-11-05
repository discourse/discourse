# frozen_string_literal: true

module Jobs
  class DeliverPushNotification < ::Jobs::Base
    def execute(args)
      payload = args[:payload].with_indifferent_access
      token = args[:localization_wait_token]
      return if token && !PushNotificationLocalizationWait.claim(payload[:post_id], token)

      begin
        deliver(args, payload, held: token.present?)
      rescue StandardError
        # Lets the retry or the wait limit's delivery send it instead.
        PushNotificationLocalizationWait.unclaim(payload[:post_id], token) if token
        raise
      end
    end

    private

    def deliver(args, payload, held:)
      user = User.find_by(id: args[:user_id])
      push_window = SiteSetting.push_notification_time_window_mins
      if !user ||
           (
             !args[:bypass_time_window] && push_window > 0 &&
               user.seen_since?(push_window.minutes.ago)
           )
        return
      end

      if SiteSetting.content_localization_enabled
        post = Post.includes(:localizations).find_by(id: payload[:post_id]) if payload[:post_id]
        topic = post&.topic || (Topic.find_by(id: payload[:topic_id]) if payload[:topic_id])

        return if !held && localization_pending?(post, user) && held?(post, user, args)

        translated =
          I18n.with_locale(user.effective_locale) do
            ContentLocalization.translated_notification_fields(
              topic: topic,
              post: post,
              scope: user.guardian,
            )
          end
        translated.delete(:excerpt) if args[:keep_excerpt]
        payload.merge!(translated)
      end

      PushNotificationPusher.push(user, payload.deep_dup) if user.push_subscriptions.exists?
      HubPushNotificationPusher.push(user, payload.deep_dup)
    end

    # Translations are usually stored seconds after the post, so a push sent right
    # away would carry the original text. Plugins producing translations decide
    # whether one is still on its way for this recipient.
    def localization_pending?(post, user)
      return false if post.nil?
      return false if SiteSetting.push_notification_localization_max_wait_mins <= 0
      return false if !ContentLocalization.automatically_translate?(user.guardian)
      return false if ContentLocalization.understands?(post.locale, user.guardian)
      return false if PushNotificationLocalizationWait.done?(post.id)

      DiscoursePluginRegistry.apply_modifier(
        :deliver_push_notification_localization_pending,
        false,
        post,
        user,
      )
    end

    def held?(post, user, args)
      token =
        PushNotificationLocalizationWait.hold(
          post_id: post.id,
          locale: user.effective_locale,
          job_args: args,
        )

      # A translation stored between the check and the hold has already fired its
      # release, so look again rather than wait for the limit.
      begin
        post.reload
        still_pending = localization_pending?(post, user)
      rescue StandardError
        # Otherwise the held push would be sent alongside this job's retry.
        raise if PushNotificationLocalizationWait.claim(post.id, token)
        return true
      end

      still_pending || !PushNotificationLocalizationWait.claim(post.id, token)
    end
  end
end
