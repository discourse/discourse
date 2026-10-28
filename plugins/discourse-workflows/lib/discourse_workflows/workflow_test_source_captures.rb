# frozen_string_literal: true

module DiscourseWorkflows
  # Seeds a test's recorded responses from the run it was saved from, so an
  # external call replays what the real run received.
  module WorkflowTestSourceCaptures
    TRUNCATION_KEY = "__truncated"

    def self.from_run_data(run_data, nodes:)
      recorded_names = nodes.select { |node| records?(node) }.map { |node| node["name"].to_s }

      (run_data || {}).each_with_object({}) do |(node_name, runs), captured|
        next if recorded_names.exclude?(node_name.to_s)

        Array(runs).each do |run|
          entries = entries_for(run)
          next if entries.nil?

          captured[Simulation.occurrence_key(node_name, run["run_index"].to_i)] = entries
        end
      end
    end

    def self.records?(node)
      klass = Registry.find_node_type(node["type"], version: NodeData.type_version(node))
      klass&.simulation_declaration&.records? == true
    end

    def self.entries_for(run)
      return if run["status"] != "success"

      port = Array(run["outputs"]).first
      return if port.nil? || port["truncated"] || truncated?(port["items"])

      input_count = Array(run["inputs"]).sum { |input| input["item_count"].to_i }
      indexed = Array(port["items"]).map { |item| [paired_index(item, input_count), item] }
      return if indexed.any? { |(index, _item)| index.nil? }

      grouped = indexed.group_by(&:first)
      Array.new(grouped.keys.max.to_i + 1) do |index|
        next if !grouped.key?(index)

        outputs = grouped[index].map { |(_index, item)| item.except(Item::PAIRED_ITEM_KEY) }
        { "fingerprint" => nil, "outputs" => outputs }
      end
    end

    def self.paired_index(item, input_count)
      paired = Array.wrap(item[Item::PAIRED_ITEM_KEY]).first
      return paired["item"].to_i if paired.is_a?(Hash) && paired.key?("item")
      return paired if paired.is_a?(Integer)
      return 0 if input_count <= 1

      nil
    end

    def self.truncated?(value)
      case value
      when Hash
        value.key?(TRUNCATION_KEY) || value.values.any? { |entry| truncated?(entry) }
      when Array
        value.any? { |entry| truncated?(entry) }
      else
        false
      end
    end
  end
end
