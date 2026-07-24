# frozen_string_literal: true

module DataTableHelpers
  def data_table_facade(data_table)
    DiscourseWorkflows::DataTables::Facade.new(data_table.reload)
  end

  def insert_data_table_row(data_table, data = {})
    dt = data_table.reload
    facade = DiscourseWorkflows::DataTables::Facade.new(dt)
    facade.insert(facade.build_row_input(data: data, fill_missing: true))
  end

  def list_data_table_rows(data_table, **options)
    facade = data_table_facade(data_table)
    query =
      facade.build_query(
        filter: options[:normalized_filter],
        limit: options[:limit],
        offset: options[:offset],
        sort_by: options[:sort_by],
        sort_direction: options[:sort_direction],
        optional_filter: true,
      )

    facade.query(query)
  end

  def count_data_table_rows(data_table, normalized_filter: nil)
    facade = data_table_facade(data_table)
    query = facade.build_query(filter: normalized_filter, optional_filter: true)
    facade.count(query)
  end

  def find_data_table_row(data_table, row_id)
    data_table_facade(data_table).find_row(row_id)
  end
end

RSpec.configure { |config| config.include(DataTableHelpers) }
