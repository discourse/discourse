class TableMigrationHelper
  def self.read_only_table(table_name)
    ActiveRecord::Base.exec_sql <<-SQL
    CREATE OR REPLACE FUNCTION raise_read_only() RETURNS trigger AS $rro$
      BEGIN
        RAISE EXCEPTION 'Discourse: Table is read only';
        RETURN null;
      END
    $rro$ LANGUAGE plpgsql;
    SQL

    ActiveRecord::Base.exec_sql <<-SQL
    CREATE TRIGGER #{table_name}_read_only
    BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
    ON #{table_name}
    FOR EACH STATEMENT
    EXECUTE PROCEDURE raise_read_only();
    SQL
  end

  def self.delayed_drop(old_name:, new_name:, after_migration:, delay: nil, on_drop: nil)
    delay ||= Rails.env.production? ? 300 : 0

   sql = <<SQL
    SELECT 1
    FROM INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'public' AND
          table_name = :old_name AND
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

        ActiveRecord::Base.exec_sql("DROP TABLE #{old_name}")
    end
  end
end
