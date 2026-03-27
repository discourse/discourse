# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::Show
    include Service::Base

    params do
      attribute :data_table_id, :integer

      validates :data_table_id, presence: true
    end

    model :data_table

    private

    def fetch_data_table(params:)
      DiscourseWorkflows::DataTable.includes(:columns).find_by(id: params.data_table_id)
    end
  end
end
