# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Show
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer

      validates :data_table_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
  end
end
