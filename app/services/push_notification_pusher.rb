require_dependency 'webpush'

class PushNotificationPusher
  def self.push(user, payload)
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
      subscription = JSON.parse(subscription.data)
      send_notification(user, subscription, message)
    end
  end

  def self.subscriptions(user)
    user.push_subscriptions
  end

  def self.clear_subscriptions(user)
    user.push_subscriptions.clear
  end

  def self.subscribe(user, subscription, send_confirmation)
    data = subscription.to_json
    subscriptions = PushSubscription.where(user: user, data: data)
    subscriptions_count = subscriptions.count

    if subscriptions_count > 1
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

      send_notification(user, subscription, message)
    end
  end

  def self.unsubscribe(user, subscription)
    PushSubscription.find_by(user: user, data: subscription.to_json)&.destroy!
  end

  protected

  def self.get_badge
    if SiteSetting.site_push_notifications_icon_url.present?
      SiteSetting.site_push_notifications_icon_url
    else
      ActionController::Base.helpers.image_url("push-notifications/discourse.png")
    end
  end

  def self.send_notification(user, subscription, message)
    begin
      Webpush.payload_send(
        endpoint: subscription["endpoint"],
        message: message.to_json,
        p256dh: subscription.dig("keys", "p256dh"),
        auth: subscription.dig("keys", "auth"),
        vapid: {
          subject: Discourse.base_url,
          public_key: SiteSetting.vapid_public_key,
          private_key: SiteSetting.vapid_private_key
        }
      )
    rescue Webpush::ExpiredSubscription
      unsubscribe(user, subscription)
    rescue Webpush::ResponseError => e
      Discourse.warn_exception(
        e,
        message: "Failed to send push notification",
        env: {
          user_id: user.id,
          endpoint: subscription["endpoint"],
          message: message.to_json
        }
      )
    end
  end
end
