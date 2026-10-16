# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    # A compact view of the current graph for the authoring prompt; full node data comes from
    # workflow_node_details.
    module WorkflowOutline
      MAX_NODES = 300
      MAX_CONNECTIONS = 600
      MAX_NOTE_LENGTH = 2_000
      STICKY_NOTE_TYPE = "flow:sticky_note"

      def self.text(workflow)
        nodes = workflow&.nodes || []
        return "The workflow has no nodes yet." if nodes.empty?

        connections =
          DiscourseWorkflows::WorkflowDocument.connection_records(nodes, workflow.connections || {})
        names_by_id = nodes.to_h { |node| [node["id"].to_s, node["name"]] }

        [
          "Nodes (id | name | type):",
          *capped(nodes, MAX_NODES, "nodes", omitted_ids: true) { |node| node_line(node) },
          "Connections:",
          *capped(connections, MAX_CONNECTIONS, "connections") do |c|
            connection_line(c, names_by_id)
          end,
        ].join("\n")
      end

      def self.capped(records, max, label, omitted_ids: false, &block)
        lines = records.first(max).map(&block)
        if records.length > max
          omitted = records.length - max
          ids = " (ids: #{records.drop(max).map { |node| node["id"] }.join(", ")})" if omitted_ids
          lines << "- [truncated: #{omitted} more #{label} not shown#{ids}; use workflow_node_details]"
        end
        lines.presence || ["- none"]
      end

      def self.node_line(node)
        line = "- #{node["id"]} | #{node["name"]} | #{node["type"]}"
        return line if node["type"] != STICKY_NOTE_TYPE

        content = DiscourseWorkflows::NodeData.parameters(node)["content"]
        return line if content.blank?

        line = "#{line} | note: #{Truncation.text(content, MAX_NOTE_LENGTH).to_json}"
        line += " (full note: workflow_node_details)" if content.length > MAX_NOTE_LENGTH
        line
      end

      def self.connection_line(connection, names_by_id)
        from = names_by_id[connection["source_node_id"].to_s] || connection["source_node_id"]
        to = names_by_id[connection["target_node_id"].to_s] || connection["target_node_id"]
        output_index = connection["source_output_index"].to_i
        input_index = connection["target_input_index"].to_i
        connection_type = connection["connection_type"].to_s.presence || "main"

        line = +"- #{from}"
        line << " [output #{output_index}]" if output_index > 0
        line << " -> #{to}"
        line << " [input #{input_index}]" if input_index > 0
        line << " (#{connection_type})" if connection_type != "main"
        line
      end
    end
  end
end
