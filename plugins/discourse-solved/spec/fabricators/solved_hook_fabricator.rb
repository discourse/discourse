# frozen_string_literal: true

Fabricator(:solved_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types =
      WebHookEventType.where(name: %w[accepted_solution unaccepted_solution])
  end
end
