# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::List
    include Service::Base

    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    policy :can_manage_workflows

    params do
      attribute :cursor, :integer
      attribute :limit, :integer
      attribute :type, :string

      before_validation { self.limit = [[limit.to_i, 1].max, MAX_LIMIT].min if limit.present? }
    end

    step :list_credentials

    private

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

    def list_credentials(params:)
      limit = params.limit || DEFAULT_LIMIT

      scope = DiscourseWorkflows::Credential.order(id: :desc)
      scope = scope.where("id < ?", params.cursor) if params.cursor
      scope = scope.where(credential_type: params.type) if params.type.present?

      results = scope.limit(limit + 1).to_a
      has_more = results.size > limit

      context[:credentials] = has_more ? results.first(limit) : results
      context[:total_rows] = if params.type.present?
        DiscourseWorkflows::Credential.where(credential_type: params.type).count
      else
        DiscourseWorkflows::Credential.count
      end
      context[:load_more_url] = if has_more
        url =
          "/admin/plugins/discourse-workflows/credentials.json?cursor=#{context[:credentials].last.id}&limit=#{limit}"
        url += "&type=#{params.type}" if params.type.present?
        url
      end
    end
  end
end
