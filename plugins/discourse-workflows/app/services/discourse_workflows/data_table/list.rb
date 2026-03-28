# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::List
    include Service::Base

    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    params do
      attribute :cursor, :integer
      attribute :limit, :integer

      before_validation { self.limit = [[limit.to_i, 1].max, MAX_LIMIT].min if limit.present? }

      def normalized_limit
        limit || DEFAULT_LIMIT
      end
    end

    step :list_data_tables
    step :compute_metadata

    private

    def list_data_tables(params:)
      scope = DiscourseWorkflows::DataTable.includes(:columns).order(id: :desc)
      scope = scope.where("id < ?", params.cursor) if params.cursor

      results = scope.limit(params.normalized_limit + 1).to_a
      context[:has_more] = results.size > params.normalized_limit
      context[:data_tables] = context[:has_more] ? results.first(params.normalized_limit) : results
    end

    def compute_metadata(data_tables:, params:, has_more:)
      context[:table_sizes] = DiscourseWorkflows::DataTableStorage.batch_size_bytes(
        data_tables.map(&:id),
      )
      context[:total_rows] = DiscourseWorkflows::DataTable.count
      context[:load_more_url] = if has_more
        "/admin/plugins/discourse-workflows/data-tables.json?cursor=#{data_tables.last.id}&limit=#{params.normalized_limit}"
      end
    end
  end
end
