# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableFacade
    class Query
      include ActiveModel::Validations

      attr_reader :normalized_filter, :limit, :offset, :sort_by, :sort_direction

      validate :check_filter_errors

      def initialize(
        data_table:,
        filter: nil,
        limit: nil,
        offset: nil,
        sort_by: nil,
        sort_direction: nil,
        optional_filter: false
      )
        normalized_filter =
          DiscourseWorkflows::NormalizedFilter.new(data_table:, filter:, optional: optional_filter)

        @invalid_filter = normalized_filter if normalized_filter.invalid?
        @normalized_filter = normalized_filter.value
        @limit = limit
        @offset = offset
        @sort_by = sort_by
        @sort_direction = sort_direction
      end

      def has_changes_to_save?
        true
      end

      private

      def check_filter_errors
        @invalid_filter&.errors&.full_messages&.each { |message| errors.add(:base, message) }
      end
    end

    class RowInput
      include ActiveModel::Validations

      attr_reader :columns

      validate :check_normalization_error

      def initialize(data_table:, data:, fill_missing: false)
        @columns = DataTableRow.normalize_row_data(data_table, data, fill_missing: fill_missing)
      rescue ArgumentError => e
        @normalization_error = e.message
        @columns = {}
      end

      def has_changes_to_save?
        true
      end

      private

      def check_normalization_error
        errors.add(:base, @normalization_error) if @normalization_error.present?
      end
    end

    class << self
      def count_for(data_table)
        new(data_table).count
      end

      def within_storage_limit?
        DataTableSizeValidator.within_limit?
      end

      def reset_storage_cache!
        DataTableSizeValidator.reset!
      end

      def total_size_bytes
        DataTableStorage.total_size_bytes
      end

      def batch_size_bytes(data_table_ids)
        DataTableStorage.batch_size_bytes(data_table_ids)
      end

      def size_bytes(data_table_id)
        DataTableStorage.size_bytes(data_table_id)
      end

      def create_table!(data_table, columns: [])
        DataTableStorage.create_table!(data_table, columns: columns)
      end

      def drop_table!(data_table_id)
        DataTableStorage.drop_table!(data_table_id)
      end
    end

    def initialize(data_table)
      @data_table = data_table
      @table_name = DataTableStorage.table_name(data_table.id)
      @table = Arel::Table.new(@table_name)
      @query_builder = DataTableQueryBuilder.new(@table)
    end

    def build_query(**options)
      Query.new(data_table: @data_table, **options)
    end

    def build_row_input(**options)
      RowInput.new(data_table: @data_table, **options)
    end

    def query(query)
      query_rows(query)
    end

    def find_row(row_id)
      query = @table.project(Arel.star).where(@table[:id].eq(row_id))
      connection.exec_query(query.to_sql).to_a.first&.then { |row| serialize_row(row) }
    end

    def count(query = nil)
      count_rows(normalized_filter: query&.normalized_filter)
    end

    def insert(row_input)
      insert_row(row_input.columns)
    end

    def update_row(row_id:, row_input:)
      return nil if row_input.columns.empty?

      um = build_update_manager(row_input.columns)
      um.where(@table[:id].eq(row_id))
      connection
        .exec_query("#{um.to_sql} RETURNING *")
        .to_a
        .first
        &.then { |row| serialize_row(row) }
    end

    def update(query:, row_input:)
      return 0 if row_input.columns.empty?

      um = build_update_manager(row_input.columns)
      um = @query_builder.apply_filters(um, query.normalized_filter)
      connection.exec_update(um.to_sql)
    end

    def delete_row(row_id)
      dm = Arel::DeleteManager.new
      dm.from(@table)
      dm.where(@table[:id].eq(row_id))
      connection.exec_query("#{dm.to_sql} RETURNING #{quoted_column("id")}").to_a.any?
    end

    def delete(query:)
      dm = Arel::DeleteManager.new
      dm.from(@table)
      dm = @query_builder.apply_filters(dm, query.normalized_filter)
      connection.exec_delete(dm.to_sql)
    end

    def delete_rows(row_ids)
      return 0 if row_ids.empty?

      dm = Arel::DeleteManager.new
      dm.from(@table)
      dm.where(@table[:id].in(row_ids))
      connection.exec_delete(dm.to_sql)
    end

    def upsert(query:, row_input:)
      return { operation: "insert", row: insert(row_input) } if row_input.columns.empty?

      updated_count = update(query:, row_input:)

      if updated_count > 0
        { operation: "update", updated_count: updated_count }
      else
        { operation: "insert", row: insert(row_input) }
      end
    end

    def add_column!(name, type)
      with_lock_timeout do
        connection.add_column(@table_name, name, DataTableStorage::SCHEMA_TYPES.fetch(type))
      end
    end

    def rename_column!(old_name:, new_name:)
      with_lock_timeout { connection.rename_column(@table_name, old_name, new_name) }
    end

    def drop_column!(column_name)
      with_lock_timeout { connection.remove_column(@table_name, column_name) }
    end

    private

    def query_rows(data_query)
      query = @table.project(Arel.star, Arel.sql("COUNT(*) OVER() AS _total_count"))
      query = @query_builder.apply_filters(query, data_query.normalized_filter)
      query = @query_builder.apply_ordering(query, data_query.sort_by, data_query.sort_direction)
      query = @query_builder.apply_pagination(query, data_query.limit, data_query.offset)

      results = connection.exec_query(query.to_sql).to_a
      total_count = results.first&.[]("_total_count") || 0
      rows = results.map { |row| serialize_row(row.except("_total_count")) }

      { rows: rows, count: total_count }
    end

    def count_rows(normalized_filter: nil)
      query = @table.project(Arel.star.count)
      query = @query_builder.apply_filters(query, normalized_filter)
      connection.exec_query(query.to_sql).rows.first.first.to_i
    end

    def insert_row(normalized_data)
      result =
        if normalized_data.empty?
          im = Arel::InsertManager.new
          im.into(@table)
          connection.exec_query("#{im.to_sql} DEFAULT VALUES RETURNING *").to_a.first
        else
          execute_insert(normalized_data)
        end

      serialize_row(result)
    end

    def execute_insert(normalized_data)
      im = Arel::InsertManager.new
      im.into(@table)
      im.insert(normalized_data.map { |name, value| [@table[name], value] })
      connection.exec_query("#{im.to_sql} RETURNING *").to_a.first
    end

    def build_update_manager(normalized_data)
      um = Arel::UpdateManager.new
      um.table(@table)
      assignments =
        normalized_data.map { |name, value| [@table[name], value] } +
          [[@table[:updated_at], Arel.sql("CURRENT_TIMESTAMP")]]
      um.set(assignments)
      um
    end

    def quoted_column(name)
      DataTableStorage.quoted_column(name)
    end

    def connection
      ActiveRecord::Base.connection
    end

    def serialize_row(row)
      row.each_with_object({}) { |(key, value), result| result[key] = serialize_value(value) }
    end

    def serialize_value(value)
      return nil if value.nil?

      value.respond_to?(:iso8601) ? value.utc.iso8601 : value
    end

    def with_lock_timeout
      connection.execute("SET LOCAL lock_timeout = '#{DataTableStorage::LOCK_TIMEOUT_MS}ms'")
      yield
    rescue PG::LockNotAvailable
      raise
    end
  end
end
