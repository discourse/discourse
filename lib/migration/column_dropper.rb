require_dependency 'migration/base_dropper'

module Migration
  class ColumnDropper < BaseDropper
    def self.drop(table:, after_migration:, columns:, delay: nil, on_drop: nil, after_drop: nil)
      validate_table_name(table)
      columns.each { |column| validate_column_name(column) }

      ColumnDropper.new(
        table, columns, after_migration, delay, on_drop, after_drop
      ).delayed_drop
    end

    def self.mark_readonly(table_name, column_name)
      create_readonly_function(table_name, column_name)

      DB.exec <<~SQL
        CREATE TRIGGER #{readonly_trigger_name(table_name, column_name)}
        BEFORE INSERT OR UPDATE OF #{column_name}
        ON #{table_name}
        FOR EACH ROW
        WHEN (NEW.#{column_name} IS NOT NULL)
        EXECUTE PROCEDURE #{readonly_function_name(table_name, column_name)};
      SQL
    end

    private

    def initialize(table, columns, after_migration, delay, on_drop, after_drop)
      super(after_migration, delay, on_drop, after_drop)

      @table = table
      @columns = columns
    end

    def droppable?
      builder = DB.build(<<~SQL)
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        /*where*/
        LIMIT 1
      SQL

      builder
        .where("table_schema = 'public'")
        .where("table_name = :table")
        .where("column_name IN (:columns)")
        .where(previous_migration_done)
        .exec(table: @table,
              columns: @columns,
              delay: "#{@delay} seconds",
              after_migration: @after_migration) > 0
    end

    def execute_drop!
      @columns.each do |column|
        DB.exec <<~SQL
          DROP TRIGGER IF EXISTS #{BaseDropper.readonly_trigger_name(@table, column)} ON #{@table};
          DROP FUNCTION IF EXISTS #{BaseDropper.readonly_function_name(@table, column)} CASCADE;
        SQL

        # safe cause it is protected on method entry, can not be passed in params
        DB.exec("ALTER TABLE #{@table} DROP COLUMN IF EXISTS #{column}")
      end
    end
  end
end
