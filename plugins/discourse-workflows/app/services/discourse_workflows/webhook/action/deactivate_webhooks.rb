# frozen_string_literal: true

module DiscourseWorkflows
  class Webhook::Action::DeactivateWebhooks < Service::ActionBase
    option :workflow

    def call
      deleted = Webhook.production.where(workflow_id: workflow.id).delete_all
      ActiveWebhooks.invalidate! if deleted.positive?
      deleted
    end
  end
end
