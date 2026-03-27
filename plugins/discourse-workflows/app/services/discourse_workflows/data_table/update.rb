# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Update
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :name, :string
      attribute :columns

      validates :data_table_id, presence: true
    end

    model :data_table, :find_data_table
    step :update_data_table
    step :reset_cached_size

    private

    def find_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def update_data_table(data_table:, params:)
      attrs = {}
      attrs[:name] = params.name if params.name.present?
      attrs[:columns] = params.columns unless params.columns.nil?
      data_table.update!(attrs) if attrs.present?
    end

    def reset_cached_size
      DiscourseWorkflows::DataTableSizeValidator.reset!
    end
  end
end
