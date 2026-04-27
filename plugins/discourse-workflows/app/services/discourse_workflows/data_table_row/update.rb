# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Update
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      attribute :filter
      attribute :data, default: {}

      validates :data_table_id, presence: true
    end

    model :data_table
    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :facade, :build_facade
    policy :within_storage_limit
    model :query, :build_query
    model :row_input, :build_row_input
    step :update_matching_rows

    private

    def build_query(facade:, params:)
      facade.build_query(filter: params.filter)
    end

    def build_row_input(facade:, params:)
      facade.build_row_input(data: params.data)
    end

    def update_matching_rows(facade:, query:, row_input:)
      context[:updated_count] = facade.update(query:, row_input:)
      fail!("No rows matched filter") if context[:updated_count] == 0
    end
  end
end
