class ColumnDropper
  def self.drop(table:, after_migration:, columns:, delay: nil, on_remove: nil)
    raise ArgumentError.new("Invalid table name passed to drop #{table}") if table =~ /[^a-z0-9_]/i

    columns.each do |column|
      raise ArgumentError.new("Invalid column name passed to drop #{column}") if column =~ /[^a-z0-9_]/i
    end

    delay ||= Rails.env.production? ? 60 : 0

    sql = <<SQL
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
        on_remove&.call

        columns.each do |column|
          # safe cause it is protected on method entry, can not be passed in params
          ActiveRecord::Base.exec_sql("ALTER TABLE #{table} DROP COLUMN IF EXISTS #{column}")
        end
    end
  end
end
