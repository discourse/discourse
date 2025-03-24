# frozen_string_literal: true

module Migrations::Importer
  class CopyStep < Step
    MappingType = ::Migrations::Importer::MappingType

    NOW = "NOW()"

    INSERT_MAPPED_IDS_SQL = <<~SQL
      INSERT INTO mapped.ids (original_id, type, discourse_id)
      VALUES (?, ?, ?)
    SQL

    class << self
      # stree-ignore
      def table_name(value = (getter = true; nil))
        return @table_name if getter
        @table_name = value
      end

      # stree-ignore
      def column_names(value = (getter = true; nil))
        return @column_names if getter
        @column_names = value
      end

      def timestamp_columns?
        @timestamp_columns ||=
          @column_names&.include?(:created_at) || @column_names&.include?(:updated_at)
      end

      def store_mapped_ids(value)
        @store_mapped_ids = value
      end

      def store_mapped_ids?
        !!@store_mapped_ids
      end

      # stree-ignore
      def total_rows_query(query = (getter = true; nil), *parameters)
        return [@total_rows_query, @total_rows_query_parameters] if getter

        @total_rows_query = query
        @total_rows_query_parameters = parameters
        nil
      end

      # stree-ignore
      def rows_query(query = (getter = true; nil), *parameters)
        return [@rows_query, @rows_query_parameters] if getter

        @rows_query = query
        @rows_query_parameters = parameters
        nil
      end
    end

    def initialize(intermediate_db, discourse_db)
      super

      @last_id = 0
      @mapping_type = nil
    end

    def execute
      super

      benchmark_loading

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
      table_name = self.class.table_name || self.class.name&.demodulize&.underscore
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

      @discourse_db.fix_last_id_of(table_name) if self.class.store_mapped_ids?
      @intermediate_db.commit_transaction

      inserted_row_count
    end

    def fetch_rows(skipped_rows)
      Enumerator.new do |enumerator|
        query, parameters = self.class.rows_query
        @intermediate_db.query(query, *parameters) do |row|
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
      return if !self.class.store_mapped_ids?

      rows.each do |row|
        @intermediate_db.insert(INSERT_MAPPED_IDS_SQL, [row[:original_id], @mapping_type, row[:id]])
      end

      nil
    end

    def transform_row(row)
      if self.class.store_mapped_ids?
        row[:original_id] = row[:id]
        row[:id] = (@last_id += 1)
      end

      if self.class.timestamp_columns?
        row[:created_at] ||= NOW
        row[:updated_at] = row[:created_at]
      end

      row
    end

    def find_mapping_type(table_name)
      constant_name = table_name.to_s.upcase

      if MappingType.const_defined?(constant_name)
        MappingType.const_get(constant_name)
      else
        raise "MappingType::#{constant_name} is not defined"
      end
    end

    def total_count
      query, parameters = self.class.total_rows_query
      @intermediate_db.count(query, *parameters)
    end

    def benchmark_loading
      start = Time.now

      # @emails = UserEmail.pluck(:email, :user_id).to_h
      # @external_ids = SingleSignOnRecord.pluck(:external_id, :user_id).to_h
      @usernames_lower = User.unscoped.pluck(:username_lower, :id)

      # @topic_users = TopicUser.unscoped.pluck(:topic_id, :user_id).to_set

      puts "Loading done in #{Time.now - start} seconds"

      start = Time.now

      @intermediate_db.execute <<~SQL
        CREATE TEMP TABLE usernames_lower (
          username TEXT PRIMARY KEY,
          discourse_user_id NUMBER
        )
      SQL

      sql = <<~SQL
        INSERT INTO usernames_lower (username, discourse_user_id)
        VALUES (?, ?)
      SQL

      @usernames_lower.each { |row| @intermediate_db.insert(sql, row) }

      puts "Writing done in #{Time.now - start} seconds"
    end
  end
end
