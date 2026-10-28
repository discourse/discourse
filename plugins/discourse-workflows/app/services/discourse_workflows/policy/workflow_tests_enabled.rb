# frozen_string_literal: true

module DiscourseWorkflows
  class Policy::WorkflowTestsEnabled < Service::PolicyBase
    def call
      SiteSetting.discourse_workflows_tests_enabled
    end

    def reason
      I18n.t("discourse_workflows.tests.errors.not_enabled")
    end
  end
end
