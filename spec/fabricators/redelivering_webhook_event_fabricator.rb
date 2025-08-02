# frozen_string_literal: true

Fabricator(:redelivering_webhook_event) do
  web_hook_event_id { Fabricate(:web_hook_event).id }
  processing false
end
