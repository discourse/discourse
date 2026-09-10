# frozen_string_literal: true

module DiscourseWorkflows
  class SettingValueResolver
    def initialize(schema)
      @schema = Array(schema)
    end

    def resolve
      @schema.each_with_object({}) do |field, result|
        key = field["key"]
        next if key.blank?

        result[key] = typed_value(field["type"], field["value"])
      end
    end

    private

    def typed_value(type, raw_value)
      case type
      when "integer", "category", "group"
        raw_value.presence&.to_i
      when "boolean"
        raw_value == "true"
      when "category_list", "group_list"
        split(raw_value).filter_map { |id| Integer(id, exception: false) }
      when "tag_list", "simple_list"
        split(raw_value)
      else
        raw_value
      end
    end

    def split(raw_value)
      raw_value.to_s.split("|").filter_map(&:presence)
    end
  end
end
