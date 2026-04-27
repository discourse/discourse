# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::List
    include Service::Base

    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :cursor, :integer
      attribute :limit, :integer
      attribute :type, :string

      before_validation do
        self.limit = limit.to_i.clamp(1, Credential::List::MAX_LIMIT) if limit.present?
      end

      def resolved_limit
        limit || Credential::List::DEFAULT_LIMIT
      end
    end

    model :credentials, optional: true
    model :total_rows, :count_total_rows
    model :load_more_url, :build_load_more_url, optional: true
    model :truncated_credentials, :truncate_credentials, optional: true

    private

    def fetch_credentials(params:)
      scope = DiscourseWorkflows::Credential.order(id: :desc)
      scope = scope.where(credential_type: params.type) if params.type.present?
      scope = scope.where("id < ?", params.cursor) if params.cursor
      scope.limit(params.resolved_limit + 1).to_a
    end

    def count_total_rows(params:)
      scope = DiscourseWorkflows::Credential
      scope = scope.where(credential_type: params.type) if params.type.present?
      scope.count
    end

    def build_load_more_url(params:, credentials:)
      limit = params.resolved_limit
      return if credentials.size <= limit

      last_id = credentials[limit - 1].id
      url = "/admin/plugins/discourse-workflows/credentials.json?cursor=#{last_id}&limit=#{limit}"
      url += "&type=#{params.type}" if params.type.present?
      url
    end

    def truncate_credentials(params:, credentials:)
      credentials.first(params.resolved_limit)
    end
  end
end
