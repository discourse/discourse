# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Destroy
    include Service::Base
    include Concerns::DataTableServiceHelpers

    MAX_BULK_DELETE = 500

    params do
      attribute :data_table_id, :integer
      attribute :row_id, :integer
      attribute :row_ids, :array
      attribute :filter

      before_validation { self.row_ids = row_ids.map(&:to_i).uniq if row_ids.present? }

      validates :data_table_id, presence: true
      validates :row_ids, length: { maximum: MAX_BULK_DELETE }, allow_nil: true
      validate :at_least_one_target

      def at_least_one_target
        return if row_id.present? || row_ids.present? || !filter.nil?
        errors.add(:base, "one of row_id, row_ids, or filter must be provided")
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :data_table
    model :facade, :build_facade

    only_if(:single_row_mode?) do
      model :row, :fetch_row
      model :deleted_count, :delete_batch_rows
    end

    only_if(:batch_mode?) { model :deleted_count, :delete_batch_rows }

    only_if(:filter_mode?) do
      model :query, :build_query
      model :deleted_count, :delete_filtered_rows
    end

    private

    def single_row_mode?(params:)
      params.row_id.present?
    end

    def batch_mode?(params:)
      params.row_ids.present?
    end

    def filter_mode?(params:)
      !params.filter.nil?
    end

    def fetch_row(facade:, params:)
      facade.find_row(params.row_id)
    end

    def build_query(facade:, params:)
      facade.build_query(filter: params.filter)
    end

    def delete_batch_rows(facade:, params:)
      ids = params.row_ids.presence || [params.row_id]
      facade.delete_rows(ids)
    end

    def delete_filtered_rows(facade:, query:)
      facade.delete(query:)
    end
  end
end
