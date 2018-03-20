require_dependency 'migration/base_dropper'

module Migration
  class Migration::TableDropper < BaseDropper
    def self.delayed_drop(old_name:, new_name:, after_migration:, delay: nil, on_drop: nil)
      validate_table_name(old_name)
      validate_table_name(new_name)

      TableDropper.new(old_name, new_name, after_migration, delay, on_drop).delayed_drop
    end

    def self.read_only_table(table_name)
      create_readonly_function(table_name)

      ActiveRecord::Base.exec_sql <<~SQL
        CREATE TRIGGER #{readonly_trigger_name(table_name)}
        BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
        ON #{table_name}
        FOR EACH STATEMENT
        EXECUTE PROCEDURE #{readonly_function_name(table_name)};
      SQL
    end

    private

    def initialize(old_name, new_name, after_migration, delay, on_drop)
      super(after_migration, delay, on_drop)

      @old_name = old_name
      @new_name = new_name
    end

    def droppable?
      builder = SqlBuilder.new(<<~SQL)
        SELECT 1
        FROM INFORMATION_SCHEMA.TABLES
        /*where*/
        LIMIT 1
      SQL

      builder.where("table_schema = 'public'")
        .where(previous_migration_done)
        .where(new_table_exists)
        .exec(old_name: @old_name,
              new_name: @new_name,
              delay: "#{@delay} seconds",
              after_migration: @after_migration).to_a.length > 0
    end

    def new_table_exists
      <<~SQL
        EXISTS(
            SELECT 1
            FROM INFORMATION_SCHEMA.TABLES
            WHERE table_schema = 'public' AND
                  table_name = :new_name
        )
      SQL
    end

    def execute_drop!
      ActiveRecord::Base.exec_sql("DROP TABLE IF EXISTS #{@old_name}")

      ActiveRecord::Base.exec_sql <<~SQL
        DROP FUNCTION IF EXISTS #{BaseDropper.readonly_function_name(@old_name)} CASCADE;
      SQL
    end
  end
end
