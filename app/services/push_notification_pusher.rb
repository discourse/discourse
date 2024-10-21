# frozen_string_literal: true

class PushNotificationPusher
  TOKEN_VALID_FOR_SECONDS = 5 * 60
  CONNECTION_TIMEOUT_SECONDS = 5

  def self.push(user, payload)
    message = nil
    I18n.with_locale(user.effective_locale) do
      notification_icon_name = Notification.types[payload[:notification_type]]
      if !File.exist?(
           File.expand_path(
             "../../app/assets/images/push-notifications/#{notification_icon_name}.png",
             __dir__,
           ),
         )
        notification_icon_name = "discourse"
      end
      notification_icon =
        ActionController::Base.helpers.image_url("push-notifications/#{notification_icon_name}.png")

      message = {
        title: payload[:translated_title] || title(payload),
        body: payload[:excerpt],
        badge: get_badge,
        icon: notification_icon,
        tag: payload[:tag] || "#{Discourse.current_hostname}-#{payload[:topic_id]}",
        base_url: Discourse.base_url,
        url: payload[:post_url],
      }

      subscriptions(user).each { |subscription| send_notification(user, subscription, message) }
    end

    message
  end

  def self.title(payload)
    translation_key =
      case payload[:notification_type]
      when Notification.types[:watching_category_or_tag]
        # For watching_category_or_tag, the notification could be for either a new post or new topic.
        # Instead of duplicating translations, we can rely on 'watching_first_post' for new topics,
        # and 'posted' for new posts.
        type = payload[:post_number] == 1 ? "watching_first_post" : "posted"
        "discourse_push_notifications.popup.#{type}"
      else
        "discourse_push_notifications.popup.#{Notification.types[payload[:notification_type]]}"
      end

    # Payload modifier used to adjust arguments to the translation
    payload =
      DiscoursePluginRegistry.apply_modifier(:push_notification_pusher_title_payload, payload)

    I18n.t(
      translation_key,
      site_title: SiteSetting.title,
      topic: payload[:topic_title],
      username: payload[:username],
      group_name: payload[:group_name],
    )
  end

  def self.subscriptions(user)
    user.push_subscriptions
  end

  def self.clear_subscriptions(user)
    user.push_subscriptions.clear
  end

  def self.subscribe(user, push_params, send_confirmation)
    data = push_params.to_json
    subscriptions = PushSubscription.where(user: user, data: data)
    subscriptions_count = subscriptions.count

    new_subscription =
      if subscriptions_count > 1
        subscriptions.destroy_all
        PushSubscription.create!(user: user, data: data)
      elsif subscriptions_count == 0
        PushSubscription.create!(user: user, data: data)
      end

    if send_confirmation == "true"
      message = {
        title:
          I18n.t("discourse_push_notifications.popup.confirm_title", site_title: SiteSetting.title),
        body: I18n.t("discourse_push_notifications.popup.confirm_body"),
        icon: ActionController::Base.helpers.image_url("push-notifications/check.png"),
        badge: get_badge,
        tag: "#{Discourse.current_hostname}-subscription",
      }

      send_notification(user, new_subscription, message)
    end
  end

  def self.unsubscribe(user, subscription)
    PushSubscription.find_by(user: user, data: subscription.to_json)&.destroy!
  end

  def self.get_badge
    if (url = SiteSetting.site_push_notifications_icon_url).present?
      url
    else
      ActionController::Base.helpers.image_url("push-notifications/discourse.png")
    end
  end

  MAX_ERRORS = 3
  MIN_ERROR_DURATION = 86_400 # 1 day

  def self.handle_generic_error(subscription, error, user, endpoint, message)
    subscription.error_count += 1
    subscription.first_error_at ||= Time.zone.now

    delta = Time.zone.now - subscription.first_error_at
    if subscription.error_count >= MAX_ERRORS && delta > MIN_ERROR_DURATION
      subscription.destroy!
    else
      subscription.save!
    end

    Discourse.warn_exception(
      error,
      message: "Failed to send push notification",
      env: {
        user_id: user.id,
        endpoint: endpoint,
        message: message.to_json,
      },
    )
  end

  def self.send_notification(user, subscription, message)
    parsed_data = subscription.parsed_data

    endpoint = parsed_data["endpoint"]
    p256dh = parsed_data.dig("keys", "p256dh")
    auth = parsed_data.dig("keys", "auth")

    if (endpoint.blank? || p256dh.blank? || auth.blank?)
      subscription.destroy!
      return
    end

    begin
      WebPush.payload_send(
        endpoint: endpoint,
        message: message.to_json,
        p256dh: p256dh,
        auth: auth,
        vapid: {
          subject: Discourse.base_url,
          public_key: SiteSetting.vapid_public_key,
          private_key: SiteSetting.vapid_private_key,
          expiration: TOKEN_VALID_FOR_SECONDS,
        },
        open_timeout: CONNECTION_TIMEOUT_SECONDS,
        read_timeout: CONNECTION_TIMEOUT_SECONDS,
        ssl_timeout: CONNECTION_TIMEOUT_SECONDS,
      )

      if subscription.first_error_at || subscription.error_count != 0
        subscription.update_columns(error_count: 0, first_error_at: nil)
      end

      DiscourseEvent.trigger(:push_notification_sent, user, message)
    rescue WebPush::ExpiredSubscription
      subscription.destroy!
    rescue WebPush::ResponseError => e
      if e.response.message == "MismatchSenderId"
        subscription.destroy!
      else
        handle_generic_error(subscription, e, user, endpoint, message)
      end
    rescue Timeout::Error => e
      handle_generic_error(subscription, e, user, endpoint, message)
    rescue OpenSSL::SSL::SSLError => e
      handle_generic_error(subscription, e, user, endpoint, message)
    end
  end

  private_class_method :send_notification
  private_class_method :handle_generic_error
end
