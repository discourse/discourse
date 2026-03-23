# frozen_string_literal: true

module DiscourseWorkflows
  class Variable::List
    include Service::Base

    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    params do
      attribute :cursor, :integer
      attribute :limit, :integer

      before_validation { self.limit = [[limit.to_i, 1].max, MAX_LIMIT].min if limit.present? }
    end

    step :list

    private

    def list(params:)
      limit = params.limit || DEFAULT_LIMIT

      scope = DiscourseWorkflows::Variable.order(id: :desc)
      scope = scope.where("id < ?", params.cursor) if params.cursor

      results = scope.limit(limit + 1).to_a
      has_more = results.size > limit
      context[:variables] = has_more ? results.first(limit) : results
      context[:total_rows] = DiscourseWorkflows::Variable.count
      context[:load_more_url] = if has_more
        "/admin/plugins/discourse-workflows/variables.json?cursor=#{context[:variables].last.id}&limit=#{limit}"
      end
    end
  end
end
