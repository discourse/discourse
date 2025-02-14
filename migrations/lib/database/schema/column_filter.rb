# frozen_string_literal: true

class ColumnFilter
  def initialize(db, schema_config)
    @db = db
    @schema_config = schema_config
  end

  def filtered_columns(table_name, config)
    columns_by_name = @db.columns(table_name).index_by(&:name)

    if (included_columns = config.dig(:columns, :include))
      return columns_by_name.slice(*included_columns).values
    elsif (excluded_columns = config.dig(:columns, :exclude))
      columns_by_name.except!(*excluded_columns)
    end

    columns_by_name.except!(*globally_excluded_columns)
    columns_by_name.values
  end

  private

  def globally_excluded_columns
    @schema_config.dig(:global, :columns, :exclude) || []
  end
end
