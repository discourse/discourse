# frozen_string_literal: true

module Migrations::Importer
  class CopyStep < Step
    def execute
      with_progressbar { copy_data }
    end

    private

    def copy_data
      @last_id = @discourse_db.last_id_of(table_name) if mapping_type
      @discourse_db.copy_data(table_name, column_names, fetch_rows) { |rows| after_commit(rows) }
      @intermediate_db.commit_transaction
    end

    def fetch_rows
      Enumerator.new do |y|
        @intermediate_db.query(sql_query) do |row|
          if (transformed_row = transform_row(row))
            y << transformed_row
          else
            @stats.skip_count += 1
          end

          update_progressbar
        end
      end
    end

    def after_commit(rows)
      store_id_mappings(rows)
    end

    def store_id_mappings(rows)
      return unless (type = mapping_type)

      rows.each do |row|
        @intermediate_db.insert(
          "INSERT INTO mappings (original_id, type, discourse_id) VALUES (?, ?, ?)",
          [row[:original_id], type, row[:id]],
        )
      end
    end

    def sql_query
      raise NotImplementedError, "Subclasses must define `sql_query`"
    end

    def table_name
      raise NotImplementedError, "Subclasses must define `table_name`"
    end

    def column_names
      raise NotImplementedError, "Subclasses must define `column_names`"
    end

    def transform_row(row)
      raise NotImplementedError, "Subclasses must define `transform_row`"
    end

    def mapping_type
      nil
    end
  end
end
