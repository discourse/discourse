# frozen_string_literal: true

module Jobs
  class DeliverPushNotification < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      push_window = SiteSetting.push_notification_time_window_mins
      if !user ||
           (
             !args[:bypass_time_window] && push_window > 0 &&
               user.seen_since?(push_window.minutes.ago)
           )
        return
      end

      payload = args[:payload].with_indifferent_access

      if SiteSetting.content_localization_enabled
        I18n.with_locale(user.effective_locale) { localize_content!(payload) }
      end

      PushNotificationPusher.push(user, payload.deep_dup) if user.push_subscriptions.exists?
      HubPushNotificationPusher.push(user, payload.deep_dup)
    end

    private

    def localize_content!(payload)
      locale = I18n.locale.to_s.sub("-", "_")

      if (topic_id = payload[:topic_id])
        topic_localization =
          TopicLocalization.find_by(topic_id: topic_id, locale: locale) ||
            TopicLocalization.matching_locale(locale).find_by(topic_id: topic_id)
        payload[:topic_title] = topic_localization.title if topic_localization
      end

      if (post_id = payload[:post_id])
        post_localization =
          PostLocalization.find_by(post_id: post_id, locale: locale) ||
            PostLocalization.matching_locale(locale).find_by(post_id: post_id)
        if post_localization
          payload[:excerpt] = Post.excerpt(
            post_localization.cooked,
            400,
            text_entities: true,
            strip_links: true,
            remap_emoji: true,
            plain_hashtags: true,
          )
        end
      end
    end
  end
end
