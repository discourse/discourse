# frozen_string_literal: true

Fabricator(:web_hook) do
  payload_url 'https://meta.discourse.org/webhook_listener'
  content_type WebHook.content_types['application/json']
  wildcard_web_hook false
  secret 'my_lovely_secret_for_web_hook'
  verify_certificate true
  active true

  transient post_hook: WebHookEventType.find_by(name: 'post')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types << transients[:post_hook]
  end
end

Fabricator(:inactive_web_hook, from: :web_hook) do
  active false
end

Fabricator(:wildcard_web_hook, from: :web_hook) do
  wildcard_web_hook true
end

Fabricator(:topic_web_hook, from: :web_hook) do
  transient topic_hook: WebHookEventType.find_by(name: 'topic')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:topic_hook]]
  end
end

Fabricator(:post_web_hook, from: :web_hook) do
  transient topic_hook: WebHookEventType.find_by(name: 'post')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:post_hook]]
  end
end

Fabricator(:user_web_hook, from: :web_hook) do
  transient user_hook: WebHookEventType.find_by(name: 'user')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:user_hook]]
  end
end

Fabricator(:group_web_hook, from: :web_hook) do
  transient group_hook: WebHookEventType.find_by(name: 'group')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:group_hook]]
  end
end

Fabricator(:category_web_hook, from: :web_hook) do
  transient category_hook: WebHookEventType.find_by(name: 'category')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:category_hook]]
  end
end

Fabricator(:tag_web_hook, from: :web_hook) do
  transient tag_hook: WebHookEventType.find_by(name: 'tag')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:tag_hook]]
  end
end

Fabricator(:flag_web_hook, from: :web_hook) do
  transient flag_hook: WebHookEventType.find_by(name: 'flag')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:flag_hook]]
  end
end

Fabricator(:queued_post_web_hook, from: :web_hook) do
  transient queued_post_hook: WebHookEventType.find_by(name: 'queued_post')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:queued_post_hook]]
  end
end

Fabricator(:reviewable_web_hook, from: :web_hook) do
  transient reviewable_hook: WebHookEventType.find_by(name: 'reviewable')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:reviewable_hook]]
  end
end

Fabricator(:notification_web_hook, from: :web_hook) do
  transient notification_hook: WebHookEventType.find_by(name: 'notification')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:notification_hook]]
  end
end
