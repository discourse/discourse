class ColumnDropper
  def self.drop(table:, after_migration:, columns:, delay: nil, on_drop: nil)
    raise ArgumentError.new("Invalid table name passed to drop #{table}") if table =~ /[^a-z0-9_]/i

    columns.each do |column|
      raise ArgumentError.new("Invalid column name passed to drop #{column}") if column =~ /[^a-z0-9_]/i
    end

    # in production we need some extra delay to allow for slow migrations
    delay ||= Rails.env.production? ? 3600 : 0

    sql = <<~SQL
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE table_schema = 'public' AND
      table_name = :table AND
      column_name IN (:columns) AND
      EXISTS (
        SELECT 1
        FROM schema_migration_details
        WHERE name = :after_migration AND
              created_at <= (current_timestamp at time zone 'UTC' - interval :delay)
      )
    LIMIT 1
    SQL

    if ActiveRecord::Base.exec_sql(sql, table: table,
                                        columns: columns,
                                        delay: "#{delay.to_i || 0} seconds",
                                        after_migration: after_migration).to_a.length > 0
      on_drop&.call

      columns.each do |column|
        ActiveRecord::Base.exec_sql <<~SQL
        DROP TRIGGER IF EXISTS #{readonly_trigger_name(table, column)} ON #{table};
        DROP FUNCTION IF EXISTS #{readonly_function_name(table, column)} CASCADE;
        SQL

        # safe cause it is protected on method entry, can not be passed in params
        ActiveRecord::Base.exec_sql("ALTER TABLE #{table} DROP COLUMN IF EXISTS #{column}")
      end

      Discourse.reset_active_record_cache
    end
  end

  def self.mark_readonly(table_name, column_name)
    ActiveRecord::Base.exec_sql <<-SQL
    CREATE OR REPLACE FUNCTION #{readonly_function_name(table_name, column_name)} RETURNS trigger AS $rcr$
      BEGIN
        RAISE EXCEPTION 'Discourse: #{column_name} in #{table_name} is readonly';
      END
    $rcr$ LANGUAGE plpgsql;
    SQL

    ActiveRecord::Base.exec_sql <<-SQL
    CREATE TRIGGER #{readonly_trigger_name(table_name, column_name)}
    BEFORE INSERT OR UPDATE OF #{column_name}
    ON #{table_name}
    FOR EACH ROW
    WHEN (NEW.#{column_name} IS NOT NULL)
    EXECUTE PROCEDURE #{readonly_function_name(table_name, column_name)};
    SQL
  end

  private

  def self.readonly_function_name(table_name, column_name)
    "raise_#{table_name}_#{column_name}_readonly()"
  end

  def self.readonly_trigger_name(table_name, column_name)
    "#{table_name}_#{column_name}_readonly"
  end
end
