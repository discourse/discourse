# frozen_string_literal: true

Fabricator(:assign_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types = WebHookEventType.where(name: %w[assigned unassigned])
  end
end
