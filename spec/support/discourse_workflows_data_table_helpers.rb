# frozen_string_literal: true

module DataTableHelpers
  def data_table_repository(data_table)
    DiscourseWorkflows::DataTableRowsRepository.new(data_table)
  end

  def insert_data_table_row(data_table, data = {})
    data_table_repository(data_table).insert(data)
  end

  def list_data_table_rows(data_table, **options)
    data_table_repository(data_table).get_many_and_count(**options)
  end

  def count_data_table_rows(data_table, filter: nil)
    data_table_repository(data_table).count(filter: filter)
  end

  def find_data_table_row(data_table, row_id)
    data_table_repository(data_table).find(row_id)
  end
end

RSpec.configure { |config| config.include(DataTableHelpers) }
