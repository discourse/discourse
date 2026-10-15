# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    # The node types the authoring agent can choose from, preloaded into its prompt.
    module NodeMenu
      MAX_DESCRIPTION_LENGTH = 160
      # Beyond this the menu costs too much prompt to preload on every request.
      MAX_LENGTH = 16_000

      def self.text(node_classes = available_node_classes)
        node_classes
          .uniq(&:identifier)
          .sort_by(&:identifier)
          .map { |node_class| line(node_class) }
          .join("\n")
      end

      def self.available_node_classes
        DiscourseWorkflows::Registry.nodes.select do |node_class|
          node_class.palette_visible? && node_class.available?
        end
      end

      def self.line(node_class)
        type = node_class.identifier
        description =
          I18n.t("js.discourse_workflows.node_descriptions.#{type}", locale: :en, default: "")
        return "- #{type}" if description.blank?

        "- #{type}: #{Truncation.text(description, MAX_DESCRIPTION_LENGTH)}"
      end
    end
  end
end
