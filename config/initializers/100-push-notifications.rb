# frozen_string_literal: true

return if GlobalSetting.skip_db?

require_dependency 'webpush'

def generate_vapid_key?
  SiteSetting.vapid_public_key.blank? ||
    SiteSetting.vapid_private_key.blank? ||
    SiteSetting.vapid_public_key_bytes.blank? ||
    SiteSetting.vapid_base_url != Discourse.base_url
end

SiteSetting.vapid_base_url = Discourse.base_url if SiteSetting.vapid_base_url.blank?

if generate_vapid_key?
  vapid_key = Webpush.generate_key
  SiteSetting.vapid_public_key = vapid_key.public_key
  SiteSetting.vapid_private_key = vapid_key.private_key

  SiteSetting.vapid_public_key_bytes = Base64.urlsafe_decode64(SiteSetting.vapid_public_key).bytes.join("|")
  SiteSetting.vapid_base_url = Discourse.base_url

  PushSubscription.delete_all
end

DiscourseEvent.on(:user_logged_out) do |user|
  PushNotificationPusher.clear_subscriptions(user)
end
