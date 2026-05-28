# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    class AggregateNodeProxy
      DEFAULT_TAKE = 100

      def get_project_id
        nil
      end

      def get_many_and_count(options = {})
        options = normalize_options(options)
        scope = DiscourseWorkflows::DataTable.all
        scope = apply_filter(scope, options["filter"])
        count = scope.count
        scope = apply_sort(scope, options["sort_by"])
        scope = scope.offset(options["skip"].to_i) if options["skip"].present?
        scope = scope.limit((options["take"] || DEFAULT_TAKE).to_i)

        { count: count, data: scope.map { |data_table| serialize_data_table(data_table) } }
      end

      def create_data_table(options)
        options = normalize_options(options)

        DiscourseWorkflows::DataTable.transaction do
          data_table = DiscourseWorkflows::DataTable.create!(name: options.fetch("name"))
          DiscourseWorkflows::DataTables::Facade.create_table!(
            data_table,
            columns: normalize_columns(options["columns"] || []),
          )
          serialize_data_table(data_table.reload)
        end
      end

      def delete_data_table_all
        DiscourseWorkflows::DataTable.find_each(&:destroy!)
        true
      end

      private

      def normalize_options(options)
        options.respond_to?(:to_h) ? options.to_h.deep_stringify_keys : {}
      end

      def apply_filter(scope, filter)
        return scope if filter.blank?

        filter = filter.to_h.stringify_keys
        name = filter["name"].presence
        return scope if name.blank?

        escaped = ActiveRecord::Base.sanitize_sql_like(name.downcase)
        scope.where("LOWER(name) LIKE ?", "%#{escaped}%")
      end

      def apply_sort(scope, sort_by)
        column, direction = sort_by.to_s.split(":", 2)
        direction = direction == "desc" ? :desc : :asc

        case column
        when "created_at", "createdAt"
          scope.order(created_at: direction)
        when "updated_at", "updatedAt"
          scope.order(updated_at: direction)
        else
          scope.order(name: direction)
        end
      end

      def serialize_data_table(data_table)
        {
          id: data_table.id,
          name: data_table.name,
          columns: data_table.columns.map { |column| serialize_column(column) },
        }
      end

      def serialize_column(column)
        name = DiscourseWorkflows::DataTable.column_name(column)
        type = DiscourseWorkflows::DataTable.column_type(column)
        serialized = { name: name, type: type }
        serialized[:reserved] = true if Types.system_column?(name)
        serialized
      end

      def normalize_columns(columns)
        columns.filter_map do |column|
          column = column.respond_to?(:to_h) ? column.to_h.deep_stringify_keys : {}
          name = column["name"].to_s
          type = column["type"].to_s
          next if name.blank? || type.blank?
          next unless DiscourseWorkflows::DataTable::COLUMN_NAME_FORMAT.match?(name)
          next if DiscourseWorkflows::DataTable::VALID_COLUMN_TYPES.exclude?(type)
          next if Types.system_column?(name)
          next if name.length > DiscourseWorkflows::DataTable::MAX_COLUMN_NAME_LENGTH

          { "name" => name, "type" => type }
        end
      end
    end
  end
end
