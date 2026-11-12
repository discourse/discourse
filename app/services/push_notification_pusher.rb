# frozen_string_literal: true

class PushNotificationPusher
  TOKEN_VALID_FOR_SECONDS = 5 * 60
  CONNECTION_TIMEOUT_SECONDS = 5
  DELIVERY_DEADLINE_SECONDS = 10
  SLOW_DELIVERY_SECONDS = 3
  MAX_SUBSCRIPTIONS_PER_USER = 10
  MAX_UNTRUSTED_SUBSCRIPTIONS_PER_USER = 2
  MAX_UNTRUSTED_ERRORS = 2
  SUBSCRIBE_RATE_LIMIT_PER_HOUR = 10

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
        url: payload[:post_url]&.sub(/\A#{Discourse.base_path}/, ""),
      }

      message[:actions] = payload[:actions] if payload[:actions].present?
      message[:action_data] = payload[:action_data] if payload[:action_data].present?

      trusted, untrusted = subscriptions(user).partition { |subscription| trusted?(subscription) }
      trusted.each { |subscription| send_notification(user, subscription, message) }

      if untrusted.present?
        Jobs::DeliverUntrustedPushNotifications.add(user_id: user.id, message: message)
      end
    end

    message
  end

  # Called by Jobs::DeliverUntrustedPushNotifications, which limits slow hosts to one
  # background worker per site.
  def self.push_untrusted(user, message, subscription_id: nil)
    scope = subscriptions(user)
    scope = scope.where(id: subscription_id) if subscription_id

    scope
      .reject { |subscription| trusted?(subscription) }
      .first(MAX_UNTRUSTED_SUBSCRIPTIONS_PER_USER)
      .each { |subscription| send_notification(user, subscription, message) }
  end

  def self.trusted?(subscription)
    host = endpoint_host(subscription.parsed_data["endpoint"])
    return false if host.blank?

    SiteSetting.push_notification_trusted_hosts_map.any? do |trusted_host|
      host == trusted_host || host.end_with?(".#{trusted_host}")
    end
  rescue JSON::ParserError
    false
  end

  def self.endpoint_host(endpoint)
    URI.parse(endpoint.to_s).host&.downcase
  rescue URI::InvalidURIError
    nil
  end

  # Browsers hand out endpoints on the reserved .invalid TLD for revoked
  # subscriptions; they can never be delivered to.
  def self.revoked_endpoint?(endpoint)
    host = endpoint_host(endpoint)
    host.present? && (host == "invalid" || host.end_with?(".invalid"))
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
    user.push_subscriptions.order(id: :desc).limit(MAX_SUBSCRIPTIONS_PER_USER)
  end

  def self.clear_subscriptions(user)
    user.push_subscriptions.clear
  end

  def self.subscribe(user, push_params, send_confirmation)
    return if revoked_endpoint?(push_params[:endpoint])

    data = push_params.to_json
    subscriptions = PushSubscription.where(user: user, data: data)
    subscriptions_count = subscriptions.count

    new_subscription =
      if subscriptions_count > 1
        subscriptions.destroy_all
        PushSubscription.create!(user: user, data: data)
      elsif subscriptions_count == 0
        RateLimiter.new(user, "push-subscribe", SUBSCRIBE_RATE_LIMIT_PER_HOUR, 1.hour).performed!
        PushSubscription.create!(user: user, data: data)
      end

    prune_subscriptions(user) if new_subscription

    if send_confirmation == "true"
      message = {
        title:
          I18n.t("discourse_push_notifications.popup.confirm_title", site_title: SiteSetting.title),
        body: I18n.t("discourse_push_notifications.popup.confirm_body"),
        icon: ActionController::Base.helpers.image_url("push-notifications/check.png"),
        badge: get_badge,
        tag: "#{Discourse.current_hostname}-subscription",
      }

      if trusted?(new_subscription)
        send_notification(user, new_subscription, message)
      else
        Jobs::DeliverUntrustedPushNotifications.add(
          user_id: user.id,
          message: message,
          subscription_id: new_subscription.id,
        )
      end
    end
  end

  # Keeps the newest subscriptions so the most recently registered browsers still
  # receive pushes, since users have no UI to manage older ones.
  def self.prune_subscriptions(user)
    untrusted_kept = 0
    total_kept = 0

    stale_ids =
      user
        .push_subscriptions
        .order(id: :desc)
        .filter_map do |subscription|
          if !trusted?(subscription)
            next subscription.id if untrusted_kept >= MAX_UNTRUSTED_SUBSCRIPTIONS_PER_USER
            untrusted_kept += 1
          end

          next subscription.id if total_kept >= MAX_SUBSCRIPTIONS_PER_USER
          total_kept += 1
          nil
        end

    PushSubscription.where(id: stale_ids).delete_all if stale_ids.present?
  end

  def self.unsubscribe(user, subscription)
    PushSubscription.where(user: user, data: subscription.to_json).delete_all
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
    record_error(subscription)

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

  # Untrusted hosts lose the one-day grace period that covers outages at the
  # browser vendors' push services, since a slow host is the attack itself.
  def self.record_error(subscription)
    subscription.error_count += 1
    subscription.first_error_at ||= Time.zone.now

    expired =
      if trusted?(subscription)
        subscription.error_count >= MAX_ERRORS &&
          Time.zone.now - subscription.first_error_at > MIN_ERROR_DURATION
      else
        subscription.error_count >= MAX_UNTRUSTED_ERRORS
      end

    expired ? subscription.destroy! : subscription.save!
  end

  def self.monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.send_notification(user, subscription, message)
    parsed_data = subscription.parsed_data

    endpoint = parsed_data["endpoint"]
    p256dh = parsed_data.dig("keys", "p256dh")
    auth = parsed_data.dig("keys", "auth")

    if endpoint.blank? || p256dh.blank? || auth.blank? || revoked_endpoint?(endpoint)
      subscription.destroy!
      return
    end

    begin
      started_at = monotonic_now

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
        total_timeout: DELIVERY_DEADLINE_SECONDS,
      )

      if monotonic_now - started_at > SLOW_DELIVERY_SECONDS && !trusted?(subscription)
        record_error(subscription)
      elsif subscription.first_error_at || subscription.error_count != 0
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
    rescue FinalDestination::SSRFDetector::LookupFailedError,
           FinalDestination::SSRFDetector::DisallowedIpError => e
      handle_generic_error(subscription, e, user, endpoint, message)
    end
  end

  private_class_method :send_notification
  private_class_method :handle_generic_error
  private_class_method :record_error
  private_class_method :monotonic_now
  private_class_method :prune_subscriptions
  private_class_method :endpoint_host
  private_class_method :revoked_endpoint?
end
