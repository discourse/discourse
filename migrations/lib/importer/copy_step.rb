# frozen_string_literal: true

module Migrations::Importer
  class CopyStep < Step
    NOW = "NOW()"

    INSERT_MAPPING_SQL = <<~SQL
      INSERT INTO mappings (original_id, type, discourse_id)
      VALUES (?, ?, ?)
    SQL

    class << self
      # stree-ignore
      def table_name(value = (getter = true; nil))
        @table_name = value unless getter
        @table_name
      end

      # stree-ignore
      def column_names(value = (getter = true; nil))
        @column_names = value unless getter
        @column_names
      end

      def store_mapped_ids(value)
        @store_mapped_ids = value
      end

      def store_mapped_ids?
        !!@store_mapped_ids
      end

      # stree-ignore
      def total_rows_query(value = (getter = true; nil))
        @total_rows_query = value unless getter
        @total_rows_query
      end

      # stree-ignore
      def rows_query(value = (getter = true; nil))
        @rows_query = value unless getter
        @rows_query
      end
    end

    def initialize(intermediate_db, discourse_db)
      super

      @last_id = 0
      @mapping_type = nil
    end

    def execute
      max_row_count = total_count

      with_progressbar(max_row_count) do
        inserted_row_count = copy_data

        if (missing_row_count = max_row_count - inserted_row_count) > 0
          @stats.skip_count = missing_row_count
          update_progressbar(increment_by: 0)
        end
      end

      nil
    end

    private

    def copy_data
      table_name = self.class.table_name || self.class.name.demodulize.underscore
      column_names = self.class.column_names || @discourse_db.column_names(table_name)
      skipped_rows = []
      inserted_row_count = 0

      if self.class.store_mapped_ids?
        @last_id = @discourse_db.last_id_of(table_name)
        @mapping_type = find_mapping_type(table_name)
      end

      @discourse_db.copy_data(table_name, column_names, fetch_rows(skipped_rows)) do |inserted_rows|
        after_commit(inserted_rows)

        if skipped_rows.any?
          after_commit(skipped_rows)
          skipped_rows.clear
        end

        inserted_row_count += inserted_rows.size
      end

      @discourse_db.fix_last_id_of(table_name)
      @intermediate_db.commit_transaction

      inserted_row_count
    end

    def fetch_rows(skipped_rows)
      Enumerator.new do |enumerator|
        @intermediate_db.query(self.class.rows_query) do |row|
          if (transformed_row = transform_row(row))
            enumerator << transformed_row
          else
            skipped_rows << row
            @stats.skip_count += 1
          end

          update_progressbar
        end
      end
    end

    def after_commit(rows)
      return unless self.class.store_mapped_ids?

      rows.each do |row|
        @intermediate_db.insert(INSERT_MAPPING_SQL, [row[:original_id], @mapping_type, row[:id]])
      end

      nil
    end

    def transform_row(row)
      if self.class.store_mapped_ids?
        row[:original_id] = row[:id]
        row[:id] = (@last_id += 1)
      end

      row[:created_at] ||= NOW
      row[:updated_at] = row[:created_at]

      row
    end

    def find_mapping_type(table_name)
      constant_name = table_name.to_s.upcase

      if ::Migrations::Importer::MappingType.const_defined?(constant_name)
        ::Migrations::Importer::MappingType.const_get(constant_name)
      else
        raise "MappingType::#{constant_name} is not defined"
      end
    end

    def total_count
      @intermediate_db.count(self.class.total_rows_query)
    end
  end
end
