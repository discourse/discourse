require_dependency 'migration/base_dropper'

module Migration
  class Migration::TableDropper < BaseDropper
    def self.delayed_drop(table_name:, after_migration:, delay: nil, on_drop: nil, after_drop: nil)
      validate_table_name(table_name)

      TableDropper.new(
        table_name, nil, after_migration, delay, on_drop, after_drop
      ).delayed_drop
    end

    def self.delayed_rename(old_name:, new_name:, after_migration:, delay: nil, on_drop: nil, after_drop: nil)
      validate_table_name(old_name)
      validate_table_name(new_name)

      TableDropper.new(
        old_name, new_name, after_migration, delay, on_drop, after_drop
      ).delayed_drop
    end

    def self.read_only_table(table_name)
      create_readonly_function(table_name)

      DB.exec <<~SQL
        CREATE TRIGGER #{readonly_trigger_name(table_name)}
        BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
        ON #{table_name}
        FOR EACH STATEMENT
        EXECUTE PROCEDURE #{readonly_function_name(table_name)};
      SQL
    end

    private

    def initialize(old_name, new_name, after_migration, delay, on_drop, after_drop)
      super(after_migration, delay, on_drop, after_drop)

      @old_name = old_name
      @new_name = new_name
    end

    def droppable?
      builder = DB.build(<<~SQL)
        SELECT 1
        FROM INFORMATION_SCHEMA.TABLES
        /*where*/
        LIMIT 1
      SQL

      builder.where(table_exists(":new_name")) if @new_name.present?

      builder.where("table_schema = 'public'")
        .where(table_exists(":old_name"))
        .where(previous_migration_done)
        .exec(old_name: @old_name,
              new_name: @new_name,
              delay: "#{@delay} seconds",
              after_migration: @after_migration) > 0
    end

    def table_exists(table_name_placeholder)
      <<~SQL
        EXISTS(
            SELECT 1
            FROM INFORMATION_SCHEMA.TABLES
            WHERE table_schema = 'public' AND
                  table_name = #{table_name_placeholder}
        )
      SQL
    end

    def execute_drop!
      DB.exec("DROP TABLE IF EXISTS #{@old_name}")

      DB.exec <<~SQL
        DROP FUNCTION IF EXISTS #{BaseDropper.readonly_function_name(@old_name)} CASCADE;
      SQL
    end
  end
end
