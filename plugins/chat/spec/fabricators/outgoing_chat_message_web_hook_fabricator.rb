# frozen_string_literal: true

Fabricator(:outgoing_chat_message_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(
        name: %w[
          chat_message_created
          chat_message_edited
          chat_message_trashed
          chat_message_restored
        ],
      )
  end
end
