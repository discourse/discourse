# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    class NodeProxy
      attr_reader :facade
      delegate :data_table, to: :facade

      def initialize(facade)
        @facade = facade
        reset_columns_resolver
      end

      def update_data_table(options)
        options = normalize_options(options)
        @facade.data_table.update!(name: options.fetch("name"))
        true
      end

      def delete_data_table
        @facade.data_table.destroy!
        true
      end

      def get_columns
        user_columns.map.with_index { |column, index| serialize_column(column, index) }
      end

      def add_column(options)
        options = normalize_options(options)
        name = options.fetch("name").to_s
        type = options.fetch("type").to_s

        validate_column_definition!(name, type)
        @facade.add_column!(name, type)
        reset_columns_resolver
        get_columns.find { |column| column[:name] == name }
      end

      def delete_column(column_id)
        @columns_resolver.validate_column!(column_id)
        @facade.drop_column!(column_id)
        reset_columns_resolver
        true
      end

      def get_many_rows_and_count(options = {})
        options = normalize_options(options)
        query = build_query(options, optional_filter: true)
        result = @facade.query(query)

        { count: result[:count], data: result[:rows] }
      end

      def insert_rows(rows, return_type)
        inserted_rows = rows.map { |row| @facade.insert(build_row_input(row)) }

        case return_type.to_s
        when "all"
          inserted_rows
        when "id"
          inserted_rows.map { |row| { "id" => row.fetch("id") } }
        when "count"
          { "success" => true, "insertedRows" => inserted_rows.size }
        else
          raise ArgumentError, "Unsupported data table insert return type: #{return_type.inspect}"
        end
      end

      def update_rows(options)
        options = normalize_options(options)
        query = build_query(options, optional_filter: false)
        row_input = build_row_input(options["data"] || {})
        rows = @facade.query(query)[:rows]

        return dry_run_update_rows(rows, row_input) if options["dry_run"]

        rows.filter_map { |row| @facade.update_row(row_id: row.fetch("id"), row_input:) }
      end

      def upsert_row(options)
        options = normalize_options(options)
        query = build_query(options, optional_filter: false)
        row_input = build_row_input(options["data"] || {})
        matching_rows = @facade.query(query)[:rows]

        if matching_rows.present?
          return dry_run_update_rows(matching_rows, row_input) if options["dry_run"]

          matching_rows.filter_map { |row| @facade.update_row(row_id: row.fetch("id"), row_input:) }
        elsif options["dry_run"]
          [dry_run_insert_row(row_input)]
        else
          [@facade.insert(row_input)]
        end
      end

      def delete_rows(options)
        options = normalize_options(options)
        query = build_query(options, optional_filter: false)
        rows = @facade.query(query)[:rows]
        return rows if options["dry_run"]

        @facade.delete(query:)
        rows
      end

      private

      def normalize_options(options)
        options.respond_to?(:to_h) ? options.to_h.deep_stringify_keys : {}
      end

      def reset_columns_resolver
        @columns_resolver = ColumnsResolver.new(@facade.data_table)
      end

      def user_columns
        @facade.data_table.columns.filter_map do |column|
          name = DiscourseWorkflows::DataTable.column_name(column)
          next if Types.system_column?(name)

          column
        end
      end

      def serialize_column(column, index)
        name = DiscourseWorkflows::DataTable.column_name(column)
        {
          id: name,
          name: name,
          type: DiscourseWorkflows::DataTable.column_type(column),
          index: index,
          data_table_id: @facade.data_table.id,
        }
      end

      def validate_column_definition!(name, type)
        raise ArgumentError, "Column name is required" if name.blank?
        raise ArgumentError, "Column type is required" if type.blank?
        unless DiscourseWorkflows::DataTable::COLUMN_NAME_FORMAT.match?(name)
          raise ArgumentError,
                "Column name must start with a letter or underscore and contain only letters, numbers, and underscores"
        end
        if name.length > DiscourseWorkflows::DataTable::MAX_COLUMN_NAME_LENGTH
          raise ArgumentError,
                "Column name must be #{DiscourseWorkflows::DataTable::MAX_COLUMN_NAME_LENGTH} characters or fewer"
        end
        raise ArgumentError, "Column name is reserved" if Types.system_column?(name)
        if DiscourseWorkflows::DataTable::VALID_COLUMN_TYPES.exclude?(type)
          raise ArgumentError, "Unsupported column type: #{type.inspect}"
        end
        if get_columns.any? { |c| c[:name] == name }
          raise ArgumentError, "Column name already exists"
        end
      end

      def build_query(options, optional_filter:)
        sort_column, sort_direction = options["sort_by"]
        query =
          @facade.build_query(
            filter: options["filter"],
            limit: options["take"],
            offset: options["skip"],
            sort_by: sort_column,
            sort_direction: sort_direction,
            optional_filter: optional_filter,
          )
        raise_invalid(:query, query) if query.invalid?
        query
      end

      def build_row_input(data)
        row_input =
          @facade.build_row_input(data: @columns_resolver.resolve(data || {}), fill_missing: false)
        raise_invalid(:row, row_input) if row_input.invalid?
        row_input
      end

      def dry_run_update_rows(rows, row_input)
        rows.flat_map do |row|
          [
            row.merge("dryRunState" => "before"),
            row.merge(row_input.columns).merge("dryRunState" => "after"),
          ]
        end
      end

      def dry_run_insert_row(row_input)
        { "id" => nil, "created_at" => nil, "updated_at" => nil, "dryRunState" => "after" }.merge(
          row_input.columns,
        )
      end

      def raise_invalid(type, value)
        raise ArgumentError,
              I18n.t(
                "discourse_workflows.errors.data_table.invalid_#{type}",
                errors: value.errors.full_messages.join(", "),
              )
      end
    end
  end
end
