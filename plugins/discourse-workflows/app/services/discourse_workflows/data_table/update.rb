# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Update
    include Service::Base

    model :data_table
    params(default_values_from: :data_table) do
      attribute :name, :string

      validates :name, presence: true
    end
    model :data_table, :update_data_table

    step :log

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
    end

    def update_data_table(data_table:, params:)
      data_table.update(**params)
      data_table
    end

    def log(guardian:, data_table:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_updated",
        subject: data_table.name,
      )
    end
  end
end
