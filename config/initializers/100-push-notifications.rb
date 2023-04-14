# frozen_string_literal: true

return if GlobalSetting.skip_db?

Rails.application.config.to_prepare do
  require "web-push"

  def generate_vapid_key?
    SiteSetting.vapid_public_key.blank? || SiteSetting.vapid_private_key.blank? ||
      SiteSetting.vapid_public_key_bytes.blank? || SiteSetting.vapid_base_url != Discourse.base_url
  end

  SiteSetting.vapid_base_url = Discourse.base_url if SiteSetting.vapid_base_url.blank?

  if false # generate_vapid_key?
    vapid_key = WebPush.generate_key
    SiteSetting.vapid_public_key = vapid_key.public_key
    SiteSetting.vapid_private_key = vapid_key.private_key

    SiteSetting.vapid_public_key_bytes =
      Base64.urlsafe_decode64(SiteSetting.vapid_public_key).bytes.join("|")
    SiteSetting.vapid_base_url = Discourse.base_url

    PushSubscription.delete_all if ActiveRecord::Base.connection.table_exists?(:push_subscriptions)
  end

  DiscourseEvent.on(:user_logged_out) { |user| PushNotificationPusher.clear_subscriptions(user) }
end
