# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::List
    include Service::Base

    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :cursor, :integer
      attribute :limit, :integer

      before_validation { self.limit = [[limit.to_i, 1].max, MAX_LIMIT].min if limit.present? }

      def normalized_limit
        limit || DEFAULT_LIMIT
      end
    end

    model :data_tables, optional: true
    model :table_sizes, :compute_table_sizes, optional: true
    model :total_rows, :compute_total_rows
    only_if(:has_more) { model :load_more_url, :compute_load_more_url, optional: true }

    private

    def fetch_data_tables(params:)
      scope = DiscourseWorkflows::DataTable.order(id: :desc)
      scope = scope.where("id < ?", params.cursor) if params.cursor
      results = scope.limit(params.normalized_limit + 1).to_a

      context[:has_more] = results.size > params.normalized_limit
      context[:has_more] ? results.first(params.normalized_limit) : results
    end

    def compute_table_sizes(data_tables:)
      DiscourseWorkflows::DataTables::Facade.batch_size_bytes(data_tables.map(&:id))
    end

    def compute_total_rows
      DiscourseWorkflows::DataTable.count
    end

    def has_more
      context[:has_more]
    end

    def compute_load_more_url(data_tables:, params:)
      "/admin/plugins/discourse-workflows/data-tables.json?cursor=#{data_tables.last.id}&limit=#{params.normalized_limit}"
    end
  end
end
