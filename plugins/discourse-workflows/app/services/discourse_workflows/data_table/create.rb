# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Create
    include Service::Base

    params do
      attribute :name, :string
      attribute :columns, default: []

      validates :name, presence: true
    end

    model :data_table, :create_data_table
    step :log

    private

    def create_data_table(params:)
      DiscourseWorkflows::DataTable.create(name: params.name, columns: params.columns)
    end

    def log(data_table:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_created",
        subject: data_table.name,
      )
    end
  end
end
