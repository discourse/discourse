# frozen_string_literal: true

class PushNotificationPusher
  TOKEN_VALID_FOR_SECONDS ||= 5 * 60
  CONNECTION_TIMEOUT_SECONDS = 5

  def self.push(user, payload)
    I18n.with_locale(user.effective_locale) do
      message = {
        title: I18n.t(
          "discourse_push_notifications.popup.#{Notification.types[payload[:notification_type]]}",
          site_title: SiteSetting.title,
          topic: payload[:topic_title],
          username: payload[:username]
        ),
        body: payload[:excerpt],
        badge: get_badge,
        icon: ActionController::Base.helpers.image_url("push-notifications/#{Notification.types[payload[:notification_type]]}.png"),
        tag: "#{Discourse.current_hostname}-#{payload[:topic_id]}",
        base_url: Discourse.base_url,
        url: payload[:post_url],
        hide_when_active: true
      }

      subscriptions(user).each do |subscription|
        send_notification(user, subscription, message)
      end
    end
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

    new_subscription = if subscriptions_count > 1
      subscriptions.destroy_all
      PushSubscription.create!(user: user, data: data)
    elsif subscriptions_count == 0
      PushSubscription.create!(user: user, data: data)
    end

    if send_confirmation == "true"
      message = {
        title: I18n.t("discourse_push_notifications.popup.confirm_title",
                      site_title: SiteSetting.title),
        body: I18n.t("discourse_push_notifications.popup.confirm_body"),
        icon: ActionController::Base.helpers.image_url("push-notifications/check.png"),
        badge: get_badge,
        tag: "#{Discourse.current_hostname}-subscription"
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

  MAX_ERRORS ||= 3
  MIN_ERROR_DURATION ||= 86400 # 1 day

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
        message: message.to_json
      }
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
      Webpush.payload_send(
        endpoint: endpoint,
        message: message.to_json,
        p256dh: p256dh,
        auth: auth,
        vapid: {
          subject: Discourse.base_url,
          public_key: SiteSetting.vapid_public_key,
          private_key: SiteSetting.vapid_private_key,
          expiration: TOKEN_VALID_FOR_SECONDS
        },
        open_timeout: CONNECTION_TIMEOUT_SECONDS,
        read_timeout: CONNECTION_TIMEOUT_SECONDS,
        ssl_timeout: CONNECTION_TIMEOUT_SECONDS
      )

      if subscription.first_error_at || subscription.error_count != 0
        subscription.update_columns(error_count: 0, first_error_at: nil)
      end
    rescue Webpush::ExpiredSubscription
      subscription.destroy!
    rescue Webpush::ResponseError => e
      if e.response.message == "MismatchSenderId"
        subscription.destroy!
      else
        handle_generic_error(subscription, e, user, endpoint, message)
      end
    rescue Timeout::Error => e
      handle_generic_error(subscription, e, user, endpoint, message)
    end
  end

  private_class_method :send_notification
  private_class_method :handle_generic_error

end
