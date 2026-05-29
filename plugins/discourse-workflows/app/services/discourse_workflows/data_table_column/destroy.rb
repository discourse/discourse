# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn::Destroy
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      attribute :column_name, :string

      validates :data_table_id, presence: true
      validates :column_name, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    policy :column_exists
    policy :not_reserved_column

    step :drop_storage_column
    step :log

    private

    def column_exists(data_table:, params:)
      data_table.columns.any? { |c| c["name"] == params.column_name }
    end

    def not_reserved_column(params:)
      DataTables::Types::SYSTEM_COLUMN_NAMES.exclude?(params.column_name)
    end

    def drop_storage_column(data_table:, params:)
      DiscourseWorkflows::DataTables::Facade.new(data_table).drop_column!(params.column_name)
    end

    def log(guardian:, data_table:, params:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_data_table_column_destroyed",
        subject: data_table.name,
        column_name: params.column_name,
      )
    end
  end
end
