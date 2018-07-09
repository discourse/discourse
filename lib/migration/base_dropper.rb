module Migration
  class BaseDropper
    def initialize(after_migration, delay, on_drop, after_drop)
      @after_migration = after_migration
      @on_drop = on_drop
      @after_drop = after_drop

      # in production we need some extra delay to allow for slow migrations
      @delay = delay || (Rails.env.production? ? 3600 : 0)
    end

    def delayed_drop
      if droppable?
        @on_drop&.call
        execute_drop!
        @after_drop&.call

        Discourse.reset_active_record_cache
      end
    end

    private

    def droppable?
      raise NotImplementedError
    end

    def execute_drop!
      raise NotImplementedError
    end

    def previous_migration_done
      <<~SQL
        EXISTS(
            SELECT 1
            FROM schema_migration_details
            WHERE name = :after_migration AND
                  (created_at <= (current_timestamp AT TIME ZONE 'UTC' - INTERVAL :delay) OR
                   (SELECT created_at
                    FROM schema_migration_details
                    ORDER BY id ASC
                    LIMIT 1) > (current_timestamp AT TIME ZONE 'UTC' - INTERVAL '10 minutes')
                  )
        )
      SQL
    end

    def self.create_readonly_function(table_name, column_name = nil)
      message = column_name ?
                  "Discourse: #{column_name} in #{table_name} is readonly" :
                  "Discourse: #{table_name} is read only"

      DB.exec <<~SQL
        CREATE OR REPLACE FUNCTION #{readonly_function_name(table_name, column_name)} RETURNS trigger AS $rcr$
          BEGIN
            RAISE EXCEPTION '#{message}';
          END
        $rcr$ LANGUAGE plpgsql;
      SQL
    end
    private_class_method :create_readonly_function

    def self.validate_table_name(table_name)
      raise ArgumentError.new("Invalid table name passed: #{table_name}") if table_name =~ /[^a-z0-9_]/i
    end

    def self.validate_column_name(column_name)
      raise ArgumentError.new("Invalid column name passed to drop #{column_name}") if column_name =~ /[^a-z0-9_]/i
    end

    def self.readonly_function_name(table_name, column_name = nil)
      ["raise", table_name, column_name, "readonly()"].compact.join("_")
    end

    def self.readonly_trigger_name(table_name, column_name = nil)
      [table_name, column_name, "readonly"].compact.join("_")
    end
  end
end
