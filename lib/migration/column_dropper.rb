require_dependency 'migration/base_dropper'

module Migration
  class ColumnDropper
    def self.mark_readonly(table_name, column_name)
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

        DB.exec <<~SQL
          DROP FUNCTION IF EXISTS #{BaseDropper.readonly_function_name(table, column)} CASCADE;
          -- Backward compatibility for old functions created in the public
          -- schema
          DROP FUNCTION IF EXISTS #{BaseDropper.old_readonly_function_name(table, column)} CASCADE;
        SQL

        # safe cause it is protected on method entry, can not be passed in params
        DB.exec("ALTER TABLE #{table} DROP COLUMN IF EXISTS #{column}")
      end
    end
  end
end
