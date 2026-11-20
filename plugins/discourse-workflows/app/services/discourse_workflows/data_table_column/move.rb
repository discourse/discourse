# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Move
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      attribute :column_name, :string
      attribute :position, :integer

      validates :data_table_id, presence: true
      validates :column_name, presence: true
      validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    policy :column_exists
    policy :not_reserved_column

    step :move_column

    private

    def move_column(data_table:, params:)
      DataTables::Facade.new(data_table).move_column!(params.column_name, params.position)
    end
  end
end
