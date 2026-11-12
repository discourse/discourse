# frozen_string_literal: true

module DiscourseWorkflows
  module CollectionParameters
    DEFAULT_GROUP = "values"
    ASSIGNMENTS_GROUP = "assignments"

    module_function

    def rows(configuration, field_name, group: DEFAULT_GROUP)
      rows_from_value(fetch_value(configuration, field_name), group: group)
    end

    def assignments(configuration, field_name = ASSIGNMENTS_GROUP)
      rows(configuration, field_name, group: ASSIGNMENTS_GROUP)
    end

    def option_bag(configuration, field_name)
      value = fetch_value(configuration, field_name)
      value.is_a?(Hash) ? value : {}
    end

    def rows_from_value(value, group: DEFAULT_GROUP)
      case value
      when Array
        value
      when Hash
        rows = value[group.to_s] || value[group.to_sym]
        return rows if rows.is_a?(Array)
        return [rows] if rows.is_a?(Hash)

        []
      else
        []
      end
    end

    def fetch_value(configuration, field_name)
      return if configuration.blank?

      if configuration.respond_to?(:[])
        configuration[field_name.to_s] || configuration[field_name.to_sym]
      end
    end
  end
end
