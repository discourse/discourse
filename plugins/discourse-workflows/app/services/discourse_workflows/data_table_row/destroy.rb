# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRow::Destroy
    include Service::Base
    include Concerns::DataTableServiceHelpers

    params do
      attribute :data_table_id, :integer
      attribute :row_id, :integer
      attribute :row_ids, :array
      attribute :filter

      before_validation { self.row_ids = row_ids.map(&:to_i).uniq if row_ids.present? }

      validates :data_table_id, presence: true
      validate :at_least_one_target

      def at_least_one_target
        return if row_id.present? || row_ids.present? || !filter.nil?
        errors.add(:base, "one of row_id, row_ids, or filter must be provided")
      end
    end

    model :data_table
    model :facade, :build_facade

    only_if(:single_row_mode?) do
      model :row, :fetch_row
      step :destroy_batch_rows
    end

    only_if(:batch_mode?) { step :destroy_batch_rows }

    only_if(:filter_mode?) do
      model :query, :build_query
      step :destroy_filtered_rows
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

    def destroy_batch_rows(facade:, params:)
      ids = params.row_ids.presence || [params.row_id]
      context[:deleted_count] = facade.delete_rows(ids)
    end

    def destroy_filtered_rows(facade:, query:)
      context[:deleted_count] = facade.delete(query:)
    end
  end
end
