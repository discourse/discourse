# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    class NodeProxy
      attr_reader :facade
      delegate :data_table, to: :facade

      def initialize(facade)
        @facade = facade
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
        @facade.data_table.user_columns.map.with_index do |column, index|
          serialize_column(column, index)
        end
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
        columns_resolver.validate_column!(column_id)
        @facade.drop_column!(column_id)
        reset_columns_resolver
        true
      end

      def get_many_rows_and_count(options = {})
        options = normalize_options(options)
        query = build_query(options, optional_filter: true)
        with_count(@facade.query(query))
      end

      def insert_rows(rows, return_type)
        # Validate every row up front so an invalid row fails before any row is inserted.
        row_inputs =
          rows.map { |row| build_row_input(row).tap { |input| ensure_insertable!(input) } }
        inserted_rows = row_inputs.map { |row_input| @facade.insert(row_input) }

        case return_type.to_s
        when "all"
          inserted_rows
        when "id"
          inserted_rows.map { |row| { "id" => row.fetch("id") } }
        when "count"
          { "success" => true, "insertedRows" => inserted_rows.size }
        else
          raise InvalidInput, "Unsupported data table insert return type: #{return_type.inspect}"
        end
      end

      def update_rows(options)
        options = normalize_options(options)
        query = build_query(options, optional_filter: false)
        row_input = build_row_input(options["data"])

        update_matching_rows(query, row_input, options)
      end

      def upsert_row(options)
        options = normalize_options(options)
        query = build_query(options, optional_filter: false)
        row_input = build_row_input(options["data"])

        result = update_matching_rows(query, row_input, options)
        return result if result[:count] > 0

        insert_row_input(row_input, options)
      end

      def insert_row(options)
        options = normalize_options(options)
        insert_row_input(build_row_input(options["data"]), options)
      end

      def delete_rows(options)
        options = normalize_options(options)
        query = build_query(options, optional_filter: false)
        with_count(
          options["dry_run"] ? @facade.query(query) : @facade.delete(query:, returning: :rows),
        )
      end

      private

      def normalize_options(options)
        options.respond_to?(:to_h) ? options.to_h.deep_stringify_keys : {}
      end

      def columns_resolver
        @columns_resolver ||= ColumnsResolver.new(@facade.data_table)
      end

      def reset_columns_resolver
        @columns_resolver = nil
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
        raise InvalidInput, "Column name is required" if name.blank?
        raise InvalidInput, "Column type is required" if type.blank?
        unless DiscourseWorkflows::DataTable::COLUMN_NAME_FORMAT.match?(name)
          raise InvalidInput,
                "Column name must start with a letter or underscore and contain only letters, numbers, and underscores"
        end
        if name.length > DiscourseWorkflows::DataTable::MAX_COLUMN_NAME_LENGTH
          raise InvalidInput,
                "Column name must be #{DiscourseWorkflows::DataTable::MAX_COLUMN_NAME_LENGTH} characters or fewer"
        end
        raise InvalidInput, "Column name is reserved" if Types.system_column?(name)
        if DiscourseWorkflows::DataTable::VALID_COLUMN_TYPES.exclude?(type)
          raise InvalidInput, "Unsupported column type: #{type.inspect}"
        end
        if get_columns.any? { |c| c[:name] == name }
          raise InvalidInput, "Column name already exists"
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
          @facade.build_row_input(data: columns_resolver.resolve(data), fill_missing: false)
        raise_invalid(:row, row_input) if row_input.invalid?
        row_input
      end

      def ensure_insertable!(row_input)
        return if row_input.columns.present?

        raise InvalidInput, I18n.t("discourse_workflows.errors.data_table.no_columns_to_insert")
      end

      # Nothing to write still counts as a match, so the rows flow on unchanged.
      def update_matching_rows(query, row_input, options)
        return dry_run_update_rows(@facade.query(query), row_input) if options["dry_run"]
        return with_count(@facade.query(query)) if row_input.columns.empty?

        with_count(@facade.update(query:, row_input:, returning: :rows))
      end

      def with_count(result)
        { data: result[:rows], count: result[:count] }
      end

      def dry_run_update_rows(result, row_input)
        pairs =
          result[:rows].flat_map do |row|
            [
              row.merge("dryRunState" => "before"),
              row.merge(row_input.columns).merge("dryRunState" => "after"),
            ]
          end
        with_count(result.merge(rows: pairs))
      end

      def insert_row_input(row_input, options)
        ensure_insertable!(row_input)
        row = options["dry_run"] ? dry_run_insert_row(row_input) : @facade.insert(row_input)
        { data: [row], count: 1 }
      end

      def dry_run_insert_row(row_input)
        { "id" => nil, "created_at" => nil, "updated_at" => nil, "dryRunState" => "after" }.merge(
          row_input.columns,
        )
      end

      def raise_invalid(type, value)
        raise InvalidInput,
              I18n.t(
                "discourse_workflows.errors.data_table.invalid_#{type}",
                errors: value.errors.full_messages.join(", "),
              )
      end
    end
  end
end
