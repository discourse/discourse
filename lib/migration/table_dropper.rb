# frozen_string_literal: true

require 'migration/base_dropper'

module Migration
  class Migration::TableDropper
    def self.read_only_table(table_name)
      BaseDropper.create_readonly_function(table_name)

      DB.exec <<~SQL
        CREATE TRIGGER #{BaseDropper.readonly_trigger_name(table_name)}
        BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
        ON #{table_name}
        FOR EACH STATEMENT
        EXECUTE PROCEDURE #{BaseDropper.readonly_function_name(table_name)};
      SQL
    end

    def self.execute_drop(table_name)
      DB.exec("DROP TABLE IF EXISTS #{table_name}")
      BaseDropper.drop_readonly_function(table_name)
    end
  end
end
