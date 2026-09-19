# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::UpdateSingle
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      attribute :row_id, :integer
      attribute :data, default: -> { {} }

      validates :data_table_id, presence: true
      validates :row_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    model :facade, :build_facade
    policy :within_storage_limit
    model :existing_row
    model :row_input, :build_row_input
    model :row, :update_row

    private

    def fetch_existing_row(facade:, params:)
      facade.find_row(params.row_id)
    end

    def build_row_input(facade:, params:)
      facade.build_row_input(data: params.data)
    end

    def update_row(facade:, params:, row_input:)
      facade.update_row(row_id: params.row_id, row_input: row_input)
    end
  end
end
