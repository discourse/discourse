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
