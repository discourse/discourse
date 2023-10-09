# frozen_string_literal: true

Fabricator(:web_hook) do
  payload_url "https://meta.discourse.org/webhook_listener"
  content_type WebHook.content_types["application/json"]
  wildcard_web_hook false
  secret "my_lovely_secret_for_web_hook"
  verify_certificate true
  active true

  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(name: %w[post_created post_edited post_destroyed post_recovered])
  end
end

Fabricator(:inactive_web_hook, from: :web_hook) { active false }

Fabricator(:wildcard_web_hook, from: :web_hook) { wildcard_web_hook true }

Fabricator(:topic_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(
        name: %w[topic_created topic_revised topic_edited topic_destroyed topic_recovered],
      )
  end
end

Fabricator(:post_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(name: %w[post_created post_edited post_destroyed post_recovered])
  end
end

Fabricator(:user_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(
        name: %w[
          user_logged_in
          user_logged_out
          user_confirmed_email
          user_created
          user_approved
          user_updated
          user_destroyed
          user_suspended
          user_unsuspended
        ],
      )
  end
end

Fabricator(:group_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(name: %w[group_created group_updated group_destroyed])
  end
end

Fabricator(:category_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(name: %w[category_created category_updated category_destroyed])
  end
end

Fabricator(:tag_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(name: %w[tag_created tag_updated tag_destroyed])
  end
end

Fabricator(:reviewable_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(name: %w[reviewable_created reviewable_updated])
  end
end

Fabricator(:notification_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types = WebHookEventType.where(name: "notification_created")
  end
end

Fabricator(:user_badge_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(name: %w[user_badge_granted user_badge_revoked])
  end
end

Fabricator(:group_user_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(name: %w[user_added_to_group user_removed_from_group])
  end
end

Fabricator(:like_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types = WebHookEventType.where(name: "post_liked")
  end
end

Fabricator(:user_promoted_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types = WebHookEventType.where(name: "user_promoted")
  end
end
