# frozen_string_literal: true

require "migration/base_dropper"

module Migration
  class ColumnDropper
    def self.mark_readonly(table_name, column_name)
      has_default = DB.query_single(<<~SQL, table_name: table_name, column_name: column_name).first
        SELECT column_default IS NOT NULL
        FROM information_schema.columns
        WHERE table_name = :table_name
        AND column_name = :column_name
      SQL

      raise "You must drop a column's default value before marking it as readonly" if has_default

      BaseDropper.create_readonly_function(table_name, column_name)

      DB.exec <<~SQL
        CREATE TRIGGER #{BaseDropper.readonly_trigger_name(table_name, column_name)}
        BEFORE INSERT OR UPDATE OF #{column_name}
        ON #{table_name}
        FOR EACH ROW
        WHEN (NEW.#{column_name} IS NOT NULL)
        EXECUTE PROCEDURE #{BaseDropper.readonly_function_name(table_name, column_name)};
      SQL
    end

    def self.execute_drop(table, columns)
      table = table.to_s

      columns.each do |column|
        column = column.to_s
        self.drop_readonly(table, column)
        # safe cause it is protected on method entry, can not be passed in params
        DB.exec("ALTER TABLE #{table} DROP COLUMN IF EXISTS #{column}")
      end
    end

    def self.drop_readonly(table_name, column_name)
      BaseDropper.drop_readonly_function(table_name, column_name)

      # Backward compatibility for old functions created in the public schema
      DB.exec(
        "DROP FUNCTION IF EXISTS #{BaseDropper.old_readonly_function_name(table_name, column_name)} CASCADE",
      )
    end
  end
end
