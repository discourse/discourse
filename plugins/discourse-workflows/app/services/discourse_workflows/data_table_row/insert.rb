# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Insert
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      attribute :data, default: -> { {} }

      validates :data_table_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    model :facade, :build_facade
    policy :within_storage_limit
    model :row_input, :build_row_input
    model :row, :insert_row

    private

    def build_row_input(facade:, params:)
      facade.build_row_input(data: params.data, fill_missing: true)
    end

    def insert_row(facade:, row_input:)
      facade.insert(row_input)
    end
  end
end
