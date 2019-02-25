module Migration
  class BaseDropper
    FUNCTION_SCHEMA_NAME = "discourse_functions".freeze

    def self.create_readonly_function(table_name, column_name = nil)
      DB.exec <<~SQL
        CREATE SCHEMA IF NOT EXISTS #{FUNCTION_SCHEMA_NAME};
      SQL

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

    def self.readonly_function_name(table_name, column_name = nil)
      function_name = [
        "raise",
        table_name,
        column_name,
        "readonly()"
      ].compact.join("_")

      if DB.exec(<<~SQL).to_s == '1'
         SELECT schema_name
         FROM information_schema.schemata
         WHERE schema_name = '#{FUNCTION_SCHEMA_NAME}'
         SQL

        "#{FUNCTION_SCHEMA_NAME}.#{function_name}"
      else
        function_name
      end
    end

    def self.old_readonly_function_name(table_name, column_name = nil)
      readonly_function_name(table_name, column_name).sub(
        "#{FUNCTION_SCHEMA_NAME}.", ''
      )
    end

    def self.readonly_trigger_name(table_name, column_name = nil)
      [table_name, column_name, "readonly"].compact.join("_")
    end
  end
end
