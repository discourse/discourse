# frozen_string_literal: true

module DiscourseWorkflows
  class Policy::WorkflowsEnabled < Service::PolicyBase
    def call
      SiteSetting.discourse_workflows_enabled
    end

    def reason
      I18n.t("discourse_workflows.errors.not_enabled")
    end
  end
end
