# frozen_string_literal: true

module DiscourseWorkflows
  module NodeTypeDescriptor
    DEFAULT_I18N_PREFIX = "discourse_workflows"

    PALETTE_GROUPS = {
      "discourse_triggers" => {
        icon: "discourse-other-tab",
        label_key: "discourse_workflows.add_node.categories.discourse_triggers",
        order: 10,
      },
      "triggers" => {
        icon: "bolt",
        label_key: "discourse_workflows.add_node.categories.triggers",
        order: 20,
      },
      "discourse_actions" => {
        icon: "discourse-other-tab",
        label_key: "discourse_workflows.add_node.categories.discourse_actions",
        order: 30,
      },
      "data" => {
        icon: "table",
        label_key: "discourse_workflows.add_node.categories.data",
        order: 50,
      },
      "core" => {
        icon: "code",
        label_key: "discourse_workflows.add_node.categories.core",
        order: 60,
      },
      "flow" => {
        icon: "arrows-split-up-and-left",
        label_key: "discourse_workflows.add_node.categories.flow",
        order: 70,
      },
      "human_review" => {
        icon: "user-check",
        label_key: "discourse_workflows.add_node.categories.human_review",
        order: 80,
      },
    }.freeze

    def kind
      identifier.split(":").first
    end

    def label_key
      "#{DEFAULT_I18N_PREFIX}.nodes.#{identifier}"
    end

    def description_key
      "#{DEFAULT_I18N_PREFIX}.node_descriptions.#{identifier}"
    end

    def palette_group_id
      default_palette_group_id
    end

    def palette_group
      palette_group_definition.merge(id: palette_group_id)
    end

    def property_i18n_prefix
      DEFAULT_I18N_PREFIX
    end

    def property_i18n_scope
      identifier.split(":").last
    end

    def operation_label_key(operation)
      "#{property_i18n_prefix}.#{property_i18n_scope}.#{operation}"
    end

    def operations
      operation_field = configuration_schema[:operation]
      options = Array(operation_field&.dig(:options))

      return [] unless operation_field&.dig(:type) == :options
      return [] if options.length <= 1

      options.map { |value| { value: value, label_key: operation_label_key(value) } }
    end

    def ports
      normalize_ports(output_port_definitions)
    end

    def branching?
      ports.length > 1
    end

    def capabilities
      {
        branching: branching?,
        manually_triggerable: respond_to?(:manually_triggerable?) ? manually_triggerable? : false,
        provides_current_user:
          respond_to?(:provides_current_user?) ? provides_current_user? : false,
        result_mode: branching? ? "ports" : "items",
      }
    end

    def ui_metadata
      {
        icon: icon,
        color_key: color_key,
        label_key: label_key,
        description_key: description_key,
        palette_group: palette_group,
        property_i18n_prefix: property_i18n_prefix,
        property_i18n_scope: property_i18n_scope,
      }.compact
    end

    private

    def palette_group_definition
      PALETTE_GROUPS.fetch(palette_group_id)
    end

    def default_palette_group_id
      case kind
      when "trigger"
        "triggers"
      when "condition", "core"
        "flow"
      else
        "core"
      end
    end

    def output_port_definitions
      return Array(outputs) if respond_to?(:outputs)
      []
    end

    def normalize_ports(definitions)
      definitions.map.with_index do |definition, index|
        port = definition.is_a?(Hash) ? definition.deep_symbolize_keys : { key: definition.to_s }
        port[:key] = port.fetch(:key).to_s
        port[:primary] = index.zero? if !port.key?(:primary)
        port.compact
      end
    end
  end
end
