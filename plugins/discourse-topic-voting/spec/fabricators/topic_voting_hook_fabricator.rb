# frozen_string_literal: true

Fabricator(:topic_voting_web_hook, from: :web_hook) do
  after_build do |web_hook|
    web_hook.web_hook_event_types = WebHookEventType.where(name: %w[topic_upvote topic_unvote])
  end
end
