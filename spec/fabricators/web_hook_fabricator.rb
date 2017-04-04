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

Fabricator(:user_web_hook, from: :web_hook) do
  transient user_hook: WebHookEventType.find_by(name: 'user')

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:user_hook]]
  end
end
