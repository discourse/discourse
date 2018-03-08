class TableMigrationHelper
  def self.read_only_table(table_name)
    ActiveRecord::Base.exec_sql <<-SQL
    CREATE OR REPLACE FUNCTION #{readonly_function_name(table_name)} RETURNS trigger AS $rro$
      BEGIN
        RAISE EXCEPTION 'Discourse: Table is read only';
        RETURN null;
      END
    $rro$ LANGUAGE plpgsql;
    SQL

    ActiveRecord::Base.exec_sql <<-SQL
    CREATE TRIGGER #{readonly_trigger_name(table_name)}
    BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
    ON #{table_name}
    FOR EACH STATEMENT
    EXECUTE PROCEDURE #{readonly_function_name(table_name)};
    SQL
  end

  def self.delayed_drop(old_name:, new_name:, after_migration:, delay: nil, on_drop: nil)
    delay ||= Rails.env.production? ? 3600 : 0

   sql = <<~SQL
    SELECT 1
    FROM INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'public' AND
          EXISTS (
            SELECT 1
            FROM schema_migration_details
            WHERE name = :after_migration AND
                  created_at <= (current_timestamp at time zone 'UTC' - interval :delay)
          )
          AND EXISTS (
            SELECT 1
            FROM INFORMATION_SCHEMA.TABLES
            WHERE table_schema = 'public' AND
            table_name = :new_name
          )
    LIMIT 1
    SQL

    if ActiveRecord::Base.exec_sql(sql, old_name: old_name,
                                        new_name: new_name,
                                        delay: "#{delay.to_i || 0} seconds",
                                        after_migration: after_migration).to_a.length > 0

      on_drop&.call
      ActiveRecord::Base.exec_sql("DROP TABLE IF EXISTS #{old_name}")

      ActiveRecord::Base.exec_sql <<~SQL
      DROP TRIGGER IF EXISTS #{readonly_trigger_name(old_name)} ON #{old_name};
      DROP FUNCTION IF EXISTS #{readonly_function_name(old_name)} CASCADE;
      SQL
    end
  end

  private

    def self.readonly_function_name(table_name)
      "public.raise_#{table_name}_read_only()"
    end

    def self.readonly_trigger_name(table_name)
      "#{table_name}_read_only"
    end
end
