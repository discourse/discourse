# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable::List
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :cursor, :integer
      attribute :limit, :integer

      after_validation { self.limit = DiscourseWorkflows::Pagination.normalize_limit(limit) }
    end

    model :data_tables, optional: true
    model :table_sizes, :compute_table_sizes, optional: true
    model :total_rows, :compute_total_rows
    model :load_more_url, :compute_load_more_url, optional: true

    private

    def fetch_data_tables(params:)
      scope = DiscourseWorkflows::DataTable.order(id: :desc)
      context[:page] = DiscourseWorkflows::Pagination.cursor_page(
        scope: scope,
        cursor: params.cursor,
        limit: params.limit,
        path: "/admin/plugins/discourse-workflows/data-tables.json",
      )
      context[:page].records
    end

    def compute_table_sizes(data_tables:)
      DiscourseWorkflows::DataTables::Facade.batch_size_bytes(data_tables.map(&:id))
    end

    def compute_total_rows
      context[:page].total_rows
    end

    def compute_load_more_url
      context[:page].load_more_url
    end
  end
end
