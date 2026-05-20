# frozen_string_literal: true

# Regenerate the VAPID keypair whenever vapid_base_url drifts from Discourse.base_url —
# push subscriptions are bound to {URL, public_key}, so a hostname change invalidates them.
if SiteSetting.vapid_public_key.blank? || SiteSetting.vapid_private_key.blank? ||
     SiteSetting.vapid_public_key_bytes.blank? || SiteSetting.vapid_base_url != Discourse.base_url
  require "web-push"
  vapid_key = WebPush.generate_key

  SiteSetting.vapid_public_key = vapid_key.public_key
  SiteSetting.vapid_private_key = vapid_key.private_key
  SiteSetting.vapid_public_key_bytes =
    Base64.urlsafe_decode64(SiteSetting.vapid_public_key).bytes.join("|")
  SiteSetting.vapid_base_url = Discourse.base_url

  PushSubscription.delete_all
end
