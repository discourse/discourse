# frozen_string_literal: true

module DiscourseWorkflows
  module Item
    PAIRED_ITEM_KEY = "pairedItem"
    INCONSISTENT_ITEM_FORMAT_MESSAGE = "Every returned item must use the same format."

    class InconsistentItemFormatError < ArgumentError
    end

    def self.wrap(data = nil, paired_item: nil, **keyword_data)
      data = keyword_data if data.nil? && keyword_data.present?

      case data
      when Array
        data.map { |d| wrap(d) }
      when Hash
        item = { "json" => data.deep_stringify_keys.freeze }
        item[PAIRED_ITEM_KEY] = normalize_paired_item(paired_item) if paired_item.present?
        item
      else
        raise ArgumentError, "Item.wrap expects Hash or Array<Hash>, got #{data.class}"
      end
    end

    def self.normalize_items(execution_data)
      execution_data = stringify_result(execution_data)

      if execution_data.is_a?(Hash)
        return [normalize_item_result(execution_data)] if execution_data.key?("json")

        return [wrap(execution_data)]
      end

      if execution_data.all? { |item| item.is_a?(Hash) && item.key?("json") }
        return execution_data.map { |item| normalize_item_result(item) }
      end

      if execution_data.any? { |item| item.is_a?(Hash) && item.key?("json") }
        raise InconsistentItemFormatError, INCONSISTENT_ITEM_FORMAT_MESSAGE
      end

      execution_data.map { |item| wrap(item) }
    end

    def self.paired_item(item)
      item[PAIRED_ITEM_KEY]
    end

    def self.with_paired_item(item, paired_item)
      item.except(PAIRED_ITEM_KEY).merge(PAIRED_ITEM_KEY => normalize_paired_item(paired_item))
    end

    def self.normalize_paired_item(paired_item)
      case paired_item
      when Array
        paired_item.map { |entry| normalize_paired_item_entry(entry) }
      when Hash
        normalize_paired_item_entry(paired_item)
      when Integer
        { "item" => paired_item }
      else
        paired_item
      end
    end

    def self.normalize_paired_item_entry(entry)
      entry.deep_stringify_keys.compact
    end

    def self.normalize_item_result(result)
      if result.key?(PAIRED_ITEM_KEY)
        result[PAIRED_ITEM_KEY] = normalize_paired_item(result[PAIRED_ITEM_KEY])
      end

      result
    end

    def self.stringify_result(value)
      case value
      when Hash
        value.deep_stringify_keys
      when Array
        value.map { |item| stringify_result(item) }
      else
        value
      end
    end
  end
end
