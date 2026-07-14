# frozen_string_literal: true

module DiscourseWorkflows
  class Webhook::Action::FindWebhook < Service::ActionBase
    option :method
    option :path
    option :test_webhook, default: -> { false }

    def call
      ActiveWebhooks.find(method: method, path: path, test_webhook: test_webhook)
    end
  end
end
