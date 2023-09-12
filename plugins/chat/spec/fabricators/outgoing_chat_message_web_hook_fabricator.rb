# frozen_string_literal: true

Fabricator(:outgoing_chat_message_web_hook, from: :web_hook) do
  transient chat_message_hook: WebHookEventType.find_by(name: "chat_message")

  after_build do |web_hook, transients|
    web_hook.web_hook_event_types = [transients[:chat_message_hook]]
  end
end
