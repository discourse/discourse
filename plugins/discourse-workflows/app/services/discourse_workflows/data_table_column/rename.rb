# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Rename
    include Service::Base

    params do
      attribute :data_table_id, :integer
      attribute :column_id, :integer
      attribute :name, :string

      validates :data_table_id, presence: true
      validates :column_id, presence: true
      validates :name, presence: true
    end

    model :data_table

    transaction do
      model :column
      step :rename_column
      step :rename_storage_column
    end

    step :log

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.includes(:columns).find_by(id: params.data_table_id)
    end

    def fetch_column(data_table:, params:)
      data_table.columns.find_by(id: params.column_id)
    end

    def rename_column(column:, params:)
      column.update!(name: params.name)
    end

    def rename_storage_column(data_table:, column:)
      DiscourseWorkflows::DataTableStorage.rename_column!(
        data_table.id,
        column.name_before_last_save,
        column.name,
      )

      data_table.reload
    end

    def log(guardian:, data_table:, column:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_column_renamed",
        subject: data_table.name,
        previous_value: column.name_before_last_save,
        new_value: column.name,
      )
    end
  end
end
