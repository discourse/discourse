# frozen_string_literal: true

module DiscourseWorkflows
  class Variable::List
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :cursor, :integer
      attribute :limit, :integer

      after_validation { self.limit = DiscourseWorkflows::Pagination.normalize_limit(limit) }
    end

    model :variables, optional: true
    model :total_rows, :count_total_rows
    model :load_more_url, :build_load_more_url, optional: true

    private

    def fetch_variables(params:)
      scope = DiscourseWorkflows::Variable.includes(:created_by).order(id: :desc)
      context[:page] = DiscourseWorkflows::Pagination.cursor_page(
        scope: scope,
        cursor: params.cursor,
        limit: params.limit,
        path: "/admin/plugins/discourse-workflows/variables.json",
      )
      context[:page].records
    end

    def count_total_rows
      context[:page].total_rows
    end

    def build_load_more_url
      context[:page].load_more_url
    end
  end
end
