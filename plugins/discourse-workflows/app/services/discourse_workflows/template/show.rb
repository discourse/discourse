# frozen_string_literal: true

module DiscourseWorkflows
  class Template::Show
    include Service::Base

    params do
      attribute :template_id, :string

      validates :template_id, presence: true, format: { with: /\A[a-z0-9_-]+\z/ }
    end

    model :template
    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    private

    def fetch_template(params:)
      DiscourseWorkflows::TemplateStore.find(params.template_id)
    end
  end
end
