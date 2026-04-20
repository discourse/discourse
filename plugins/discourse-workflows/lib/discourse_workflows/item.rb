# frozen_string_literal: true

module DiscourseWorkflows
  module Item
    def self.wrap(data)
      case data
      when Array
        data.map { |d| wrap(d) }
      when Hash
        { "json" => data.deep_stringify_keys.freeze }
      else
        raise ArgumentError, "Item.wrap expects Hash or Array<Hash>, got #{data.class}"
      end
    end
  end
end
