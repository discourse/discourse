# frozen_string_literal: true

Fabricator(:web_hook) do
  payload_url "https://meta.discourse.org/webhook_listener"
  content_type WebHook.content_types["application/json"]
  wildcard_web_hook false
  secret "my_lovely_secret_for_web_hook"
  verify_certificate true
  active true

  transient post_created_hook: WebHookEventType.find_by(name: "post_created"),
            post_edited_hook: WebHookEventType.find_by(name: "post_edited"),
            post_destroyed_hook: WebHookEventType.find_by(name: "post_destroyed"),
            post_recovered_hook: WebHookEventType.find_by(name: "post_recovered")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:post_created_hook],
      transients[:post_edited_hook],
      transients[:post_destroyed_hook],
      transients[:post_recovered_hook],
    ]
  end
end

Fabricator(:inactive_web_hook, from: :web_hook) { active false }

Fabricator(:wildcard_web_hook, from: :web_hook) { wildcard_web_hook true }

Fabricator(:topic_web_hook, from: :web_hook) do
  transient topic_created_hook: WebHookEventType.find_by(name: "topic_created"),
            topic_revised_hook: WebHookEventType.find_by(name: "topic_revised"),
            topic_edited_hook: WebHookEventType.find_by(name: "topic_edited"),
            topic_destroyed_hook: WebHookEventType.find_by(name: "topic_destroyed"),
            topic_recovered_hook: WebHookEventType.find_by(name: "topic_recovered")
  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:topic_created_hook],
      transients[:topic_revised_hook],
      transients[:topic_edited_hook],
      transients[:topic_destroyed_hook],
      transients[:topic_recovered_hook],
    ]
  end
end

Fabricator(:post_web_hook, from: :web_hook) do
  transient post_created_hook: WebHookEventType.find_by(name: "post_created"),
            post_edited_hook: WebHookEventType.find_by(name: "post_edited"),
            post_destroyed_hook: WebHookEventType.find_by(name: "post_destroyed"),
            post_recovered_hook: WebHookEventType.find_by(name: "post_recovered")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:post_created_hook],
      transients[:post_edited_hook],
      transients[:post_destroyed_hook],
      transients[:post_recovered_hook],
    ]
  end
end

Fabricator(:user_web_hook, from: :web_hook) do
  transient user_logged_in_hook: WebHookEventType.find_by(name: "user_logged_in"),
            user_logged_out_hook: WebHookEventType.find_by(name: "user_logged_out"),
            user_confirmed_email_hook: WebHookEventType.find_by(name: "user_confirmed_email"),
            user_created_hook: WebHookEventType.find_by(name: "user_created"),
            user_approved_hook: WebHookEventType.find_by(name: "user_approved"),
            user_updated_hook: WebHookEventType.find_by(name: "user_updated"),
            user_destroyed_hook: WebHookEventType.find_by(name: "user_destroyed")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:user_logged_in_hook],
      transients[:user_logged_out_hook],
      transients[:user_confirmed_email_hook],
      transients[:user_created_hook],
      transients[:user_approved_hook],
      transients[:user_updated_hook],
      transients[:user_destroyed_hook],
    ]
  end
end

Fabricator(:group_web_hook, from: :web_hook) do
  transient group_created_hook: WebHookEventType.find_by(name: "group_created"),
            group_updated_hook: WebHookEventType.find_by(name: "group_updated"),
            group_destroyed_hook: WebHookEventType.find_by(name: "group_destroyed")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:group_created_hook],
      transients[:group_updated_hook],
      transients[:group_destroyed_hook],
    ]
  end
end

Fabricator(:category_web_hook, from: :web_hook) do
  transient category_created_hook: WebHookEventType.find_by(name: "category_created"),
            category_updated_hook: WebHookEventType.find_by(name: "category_updated"),
            category_destroyed_hook: WebHookEventType.find_by(name: "category_destroyed")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:category_created_hook],
      transients[:category_updated_hook],
      transients[:category_destroyed_hook],
    ]
  end
end

Fabricator(:tag_web_hook, from: :web_hook) do
  transient tag_created_hook: WebHookEventType.find_by(name: "tag_created"),
            tag_updated_hook: WebHookEventType.find_by(name: "tag_updated"),
            tag_destroyed_hook: WebHookEventType.find_by(name: "tag_destroyed")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:tag_created_hook],
      transients[:tag_updated_hook],
      transients[:tag_destroyed_hook],
    ]
  end
end

Fabricator(:reviewable_web_hook, from: :web_hook) do
  transient reviewable_created_hook: WebHookEventType.find_by(name: "reviewable_created"),
            reviewable_updated_hook: WebHookEventType.find_by(name: "reviewable_updated")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:reviewable_created_hook],
      transients[:reviewable_updated_hook],
    ]
  end
end

Fabricator(:notification_web_hook, from: :web_hook) do
  transient notification_hook: WebHookEventType.find_by(name: "notification_created")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:notification_hook]]
  end
end

Fabricator(:user_badge_web_hook, from: :web_hook) do
  transient user_badge_granted_hook: WebHookEventType.find_by(name: "user_badge_granted"),
            user_badge_revoked_hook: WebHookEventType.find_by(name: "user_badge_revoked")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:user_badge_granted_hook],
      transients[:user_badge_revoked_hook],
    ]
  end
end

Fabricator(:group_user_web_hook, from: :web_hook) do
  transient group_user_added_hook: WebHookEventType.find_by(name: "user_added_to_group"),
            group_user_removed_hook: WebHookEventType.find_by(name: "user_removed_from_group")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [
      transients[:group_user_added_hook],
      transients[:group_user_removed_hook],
    ]
  end
end

Fabricator(:like_web_hook, from: :web_hook) do
  transient like_hook: WebHookEventType.find_by(name: "post_liked")

  after_build { |web_hook, transients| web_hook.web_hook_event_types = [transients[:like_hook]] }
end

Fabricator(:user_promoted_web_hook, from: :web_hook) do
  transient user_promoted_hook: WebHookEventType.find_by(name: "user_promoted")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:user_promoted_hook]]
  end
end
