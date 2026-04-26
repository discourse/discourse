# frozen_string_literal: true

Fabricator(:outgoing_calendar_event_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(
        name: %w[calendar_event_created calendar_event_updated calendar_event_destroyed],
      )
  end
end
