# frozen_string_literal: true

module DiscourseWorkflows
  class Item
    attr_reader :json

    def initialize(json)
      @json = json.deep_stringify_keys.freeze
    end

    def to_h
      { "json" => @json }
    end

    def self.wrap(data)
      case data
      when Item
        data
      when Hash
        new(data.key?("json") ? data["json"] : data)
      else
        new({})
      end
    end

    def self.wrap_array(items)
      Array(items).map { |i| wrap(i).to_h }
    end
  end
end
