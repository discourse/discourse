# frozen_string_literal: true

module Migrations::Database
  module Schema
    Table =
      Data.define(:name, :columns, :indexes, :primary_key_column_names) do
        def sorted_columns
          columns.sort_by { |c| [c.is_primary_key ? 0 : 1, c.name] }
        end
      end
    Column = Data.define(:name, :datatype, :nullable, :max_length, :is_primary_key)
    Index = Data.define(:name, :column_names, :unique, :condition)

    class ConfigError < StandardError
    end
  end
end
