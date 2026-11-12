# frozen_string_literal: true

module DiscourseWorkflows
  module Concerns
    module DataTableServiceHelpers
      extend ActiveSupport::Concern

      private

      def fetch_data_table(params:)
        DiscourseWorkflows::DataTable.find_by(id: params.data_table_id)
      end

      def build_facade(data_table:)
        DataTables::Facade.new(data_table)
      end

      def within_storage_limit
        DataTables::Facade.within_storage_limit?
      end

      def column_exists(data_table:, params:)
        data_table.columns.any? { |c| c["name"] == params.column_name }
      end

      def not_reserved_column(params:)
        !DataTables::Types.system_column?(params.column_name)
      end
    end
  end
end
