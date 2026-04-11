# frozen_string_literal: true

module DiscourseWorkflows
  module ItemContract
    class Error < StandardError
    end

    def self.validate_items!(items, source:)
      return unless Rails.env.local?
      unless items.is_a?(Array) && items.all? { |i| i.is_a?(Hash) && i.key?("json") }
        raise Error,
              "Invalid items from #{source}: expected Array<{ 'json' => Hash }>, got #{items.inspect.truncate(200)}"
      end
    end

    def self.validate_output_arrays!(result, source:)
      return unless Rails.env.local?
      unless result.is_a?(Array) && result.all? { |inner| inner.is_a?(Array) }
        raise Error, "#{source}: execute must return Array<Array<Item>>, got #{result.class}"
      end
      result.each { |inner| validate_items!(inner, source: source) }
    end

    def self.validate_node_result!(result, source:, ports:)
      return unless Rails.env.local?
      unless result.is_a?(NodeResult)
        raise Error, "#{source}: execute must return NodeResult, got #{result.class}"
      end

      port_names = Array(ports).map { |port| port[:key].to_s }
      if port_names.present?
        unknown_outputs = result.outputs.keys - port_names
        if unknown_outputs.present?
          raise Error, "#{source}: unknown outputs #{unknown_outputs.inspect}"
        end
      elsif result.outputs.keys.many?
        raise Error, "#{source}: multiple outputs require declared ports"
      elsif result.outputs.keys.one? && result.outputs.keys.first != "main"
        raise Error, "#{source}: single output without declared ports must use 'main'"
      end

      result.outputs.each do |output_name, items|
        unless items.is_a?(Array)
          raise Error, "#{source}: output '#{output_name}' must contain an Array<Item>"
        end
        validate_items!(items, source: "#{source}:#{output_name}")
      end
    end
  end
end
