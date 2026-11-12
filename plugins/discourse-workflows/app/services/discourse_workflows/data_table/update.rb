# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Update
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      attribute :name, :string

      validates :data_table_id, presence: true
      validates :name,
                presence: true,
                length: {
                  maximum: 100,
                },
                format: {
                  with: /\A[a-zA-Z_][a-zA-Z0-9_ ]*\z/,
                }
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    model :data_table, :update_data_table

    step :log

    private

    def update_data_table(data_table:, params:)
      data_table.update(name: params.name)
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
