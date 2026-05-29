# frozen_string_literal: true

module DiscourseWorkflows
  class Template::List
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :templates, optional: true

    private

    def fetch_templates
      DiscourseWorkflows::TemplateStore.summaries
    end
  end
end
