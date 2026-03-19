# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class Scaffolder
    DSL_REFERENCE = <<~COMMENT
      # Schema DSL Reference:
      #
      #   include_all                                - Include all source columns (implied by `ignore`)
      #   include :col1, :col2                       - Include only these columns
      #   include! :col1, :col2                      - Include columns, overriding global/plugin ignores
      #   ignore :col1, :col2, reason: "..."         - Ignore columns (implies include_all)
      #   primary_key :col1, :col2                   - Override primary key
      #   column :name, required: true               - Set column options (required, type, max_length, rename_to)
      #   add_column :name, :type                    - Add a column not in the source table
      #   copy_structure_from :other_table           - Use another table as the source
      #   synthetic!                                 - Table has no source (only add_column allowed)
      #   ignore_plugin_columns!                     - Auto-ignore columns from all (or specific) non-ignored plugins
    COMMENT

    def initialize(schema_module, table_name, database: :intermediate_db)
      @schema = schema_module
      @table_name = table_name.to_s
      @database = database
    end

    def scaffold!
      ActiveRecord::Base.with_connection do |connection|
        @db = connection

        if @db.tables.exclude?(@table_name)
          raise Migrations::Database::Schema::ConfigError,
                "Table '#{@table_name}' does not exist in the database"
        end

        content = generate_table_file
        write_file(content)
      end
    end

    private

    def generate_table_file
      columns = @db.columns(@table_name)
      primary_keys = @db.primary_keys(@table_name)
      indexes = @db.indexes(@table_name)

      lines = []
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << DSL_REFERENCE.chomp
      lines << "#"
      lines.concat(source_metadata_lines(primary_keys, indexes))
      lines << ""
      lines << "Migrations::Database::Schema.table :#{@table_name} do"

      if primary_keys.size > 1
        pks = primary_keys.map { |pk| ":#{pk}" }.join(", ")
        lines << "  primary_key #{pks}"
        lines << ""
      end

      lines << "  include_all"
      lines << ""
      lines << "  # TODO: Configure columns. Run `schema validate` to check."
      lines << '  # ignore :col1, :col2, reason: "..."'
      lines << "end"
      lines.join("\n") + "\n"
    end

    def source_metadata_lines(primary_keys, indexes)
      lines = []
      lines << "# Source table: #{@table_name}"

      pk_display = primary_keys.any? ? primary_keys.join(", ") : "(none)"
      lines << "#   Primary key: #{pk_display}"

      unique_indexes = indexes.select(&:unique)

      if unique_indexes.any?
        lines << "#   Unique indexes:"
        unique_indexes.each { |idx| lines << "#     #{idx.name} (#{idx.columns.join(", ")})" }
      end

      lines
    end

    def write_file(content)
      tables_dir = File.join(Migrations::Database::Schema.config_path(@database), "tables")
      FileUtils.mkdir_p(tables_dir)

      path = File.join(tables_dir, "#{@table_name}.rb")

      if File.exist?(path)
        raise Migrations::Database::Schema::ConfigError, "Table config already exists at #{path}"
      end

      File.write(path, content)
      Migrations::Database::Schema::Helpers.format_ruby_file(path)
      path
    end
  end
end
