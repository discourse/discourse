# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class NodeResult
    attr_reader :outputs

    def self.main(items)
      new("main" => items)
    end

    def self.from_output_arrays(output_arrays, ports:)
      names = output_names_for(output_arrays.length, ports: ports)
      new(names.zip(output_arrays).to_h)
    end

    def self.output_names_for(output_count, ports:)
      names = Array(ports).map { |port| port[:key].to_s }
      return names.first(output_count) if output_count <= names.length
      return [] if output_count.zero?
      return ["main"] if output_count == 1 && names.empty?

      raise ArgumentError, "Cannot map #{output_count} outputs without declared ports"
    end

    def initialize(outputs)
      @outputs =
        outputs.to_h.transform_keys(&:to_s).transform_values { |items| items.nil? ? [] : items }
    end

    def output_arrays(ports:)
      names = Array(ports).map { |port| port[:key].to_s }
      return outputs.values if names.empty?

      names.map { |name| outputs.fetch(name, []) }
    end

    def all_items(ports:)
      output_arrays(ports: ports).flatten(1)
    end

    def primary_items(ports:)
      outputs.fetch(primary_output_name(ports), [])
    end

    private

    def primary_output_name(ports)
      primary_port = Array(ports).find { |port| port[:primary] } || Array(ports).first
      primary_port&.dig(:key).to_s.presence || outputs.keys.first || "main"
    end
    end
  end
end
