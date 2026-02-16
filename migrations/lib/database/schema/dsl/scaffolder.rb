# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class Scaffolder
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
        path = write_file(content)
        path
      end
    end

    private

    def generate_table_file
      columns = @db.columns(@table_name)
      primary_keys = @db.primary_keys(@table_name)
      indexes = @db.indexes(@table_name)

      column_names = columns.map(&:name)
      globally_ignored = globally_ignored_columns
      included_names = column_names.reject { |c| globally_ignored.include?(c) }

      lines = []
      lines << "# frozen_string_literal: true"
      lines << ""
      lines << "Migrations::Database::Schema.table :#{@table_name} do"

      if primary_keys.size > 1
        pks = primary_keys.map { |pk| ":#{pk}" }.join(", ")
        lines << "  primary_key #{pks}"
        lines << ""
      end

      if included_names.any?
        cols = included_names.map { |c| ":#{c}" }.join(", ")
        lines << "  include #{cols}"
      end

      if indexes.any?
        lines << ""
        indexes.each do |idx|
          cols = idx.columns.map { |c| c.to_s.inspect }.join(", ")
          opts = []
          opts << "name: #{idx.name.to_s.inspect}"
          opts << "where: #{idx.where.to_s.inspect}" if idx.where

          method = idx.unique ? "unique_index" : "index"
          lines << "  #{method} #{cols}, #{opts.join(", ")}"
        end
      end

      lines << "end"
      lines.join("\n") + "\n"
    end

    def write_file(content)
      tables_dir = File.join(Migrations::Database::Schema.config_path(@database), "tables")
      FileUtils.mkdir_p(tables_dir)

      path = File.join(tables_dir, "#{@table_name}.rb")

      if File.exist?(path)
        raise Migrations::Database::Schema::ConfigError, "Table config already exists at #{path}"
      end

      File.write(path, content)
      path
    end

    def globally_ignored_columns
      conventions = @schema.conventions_config
      return Set.new unless conventions
      conventions.ignored_columns.map(&:to_s).to_set
    end
  end
end
