# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Get
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      attribute :filter
      attribute :limit, :integer
      attribute :offset, :integer
      attribute :sort_by, :string
      attribute :sort_direction, :string

      validates :data_table_id, presence: true

      before_validation do
        self.limit =
          limit.to_i.clamp(1, DiscourseWorkflows::Pagination::MAX_LIMIT) if limit.present?
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    model :facade, :build_facade
    model :query, :build_query
    model :query_result, :execute_query

    private

    def build_query(facade:, params:)
      facade.build_query(
        filter: params.filter,
        limit: params.limit || DiscourseWorkflows::Pagination::DEFAULT_LIMIT,
        offset: params.offset,
        sort_by: params.sort_by,
        sort_direction: params.sort_direction,
        optional_filter: true,
      )
    end

    def execute_query(facade:, query:)
      facade.query(query)
    end
  end
end
