# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::List
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :cursor, :integer
      attribute :limit, :integer
      attribute :type, :string

      after_validation { self.limit = DiscourseWorkflows::Pagination.normalize_limit(limit) }
    end

    model :credentials, optional: true
    model :total_rows, :count_total_rows
    model :load_more_url, :build_load_more_url, optional: true

    private

    def fetch_credentials(params:)
      scope = DiscourseWorkflows::Credential.order(id: :desc)
      scope = scope.where(credential_type: params.type) if params.type.present?
      context[:page] = DiscourseWorkflows::Pagination.cursor_page(
        scope: scope,
        cursor: params.cursor,
        limit: params.limit,
        path: "/admin/plugins/discourse-workflows/credentials.json",
        query: {
          type: params.type,
        },
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
