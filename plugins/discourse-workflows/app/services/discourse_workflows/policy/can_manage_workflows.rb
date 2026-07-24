# frozen_string_literal: true

module DiscourseWorkflows
  class Policy::CanManageWorkflows < Service::PolicyBase
    def call
      guardian.can_manage_workflows?
    end

    def reason
      I18n.t("discourse_workflows.errors.no_permission_to_manage")
    end
  end
end
