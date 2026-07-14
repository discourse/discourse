# frozen_string_literal: true

module DiscourseWorkflows
  module NodeTypeDescriptor
    DEFAULT_I18N_PREFIX = "discourse_workflows"

    GROUPS = {
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
      "utilities" => {
        icon: "code",
        label_key: "discourse_workflows.add_node.categories.utilities",
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
      description[:displayName] || description[:display_name_key] ||
        "#{DEFAULT_I18N_PREFIX}.nodes.#{identifier}"
    end

    def description_key
      description[:description_key] || "#{DEFAULT_I18N_PREFIX}.node_descriptions.#{identifier}"
    end

    def group
      description[:group] || default_group
    end

    def palette_group
      group_definition.merge(id: group)
    end

    def i18n_prefix
      description[:i18n_prefix] || DEFAULT_I18N_PREFIX
    end

    def i18n_scope
      description[:i18n_scope] || identifier.split(":").last
    end

    def operation_label_key(operation)
      "#{i18n_prefix}.#{i18n_scope}.operations.#{operation}"
    end

    def operations
      operation_field = property_schema[:operation]
      options = Array(operation_field&.dig(:options))

      return [] unless operation_field&.dig(:type) == :options
      return [] if options.length <= 1

      options.map { |value| { value: value, label_key: operation_label_key(value) } }
    end

    def ports(configuration = {})
      normalize_ports(output_port_definitions(configuration))
    end

    def input_ports(configuration = {})
      normalize_ports(input_port_definitions(configuration), primary: false, required: true)
    end

    def required_inputs(configuration = {})
      description_value(:required_inputs, configuration: configuration)
    end

    def branching?
      ports.length > 1
    end

    def capabilities
      description.fetch(:capabilities, {}).merge(
        branching: branching?,
        manually_triggerable: manually_triggerable?,
        provides_current_user: provides_current_user?,
        result_mode: branching? ? "ports" : "items",
      )
    end

    def ui_metadata
      {
        icon: icon,
        color: color,
        defaults: description[:defaults],
        label_key: label_key,
        description_key: description_key,
        palette_group: palette_group,
        i18n_prefix: i18n_prefix,
        i18n_scope: i18n_scope,
      }.compact
    end

    private

    def group_definition
      GROUPS.fetch(group)
    end

    def default_group
      case kind
      when "trigger"
        "triggers"
      when "condition", "flow"
        "flow"
      else
        "utilities"
      end
    end

    def output_port_definitions(configuration = {})
      return call_port_definition(:outputs, configuration) if respond_to?(:outputs)
      []
    end

    def input_port_definitions(configuration = {})
      return call_port_definition(:inputs, configuration) if respond_to?(:inputs)
      [:main]
    end

    def call_port_definition(method_name, configuration)
      method = public_method(method_name)
      Array(method.arity.zero? ? method.call : method.call(configuration))
    end

    def normalize_ports(definitions, primary: true, required: nil)
      definitions.map.with_index do |definition, index|
        port = definition.is_a?(Hash) ? definition.deep_symbolize_keys : { key: definition.to_s }
        port[:key] = port[:key].presence&.to_s || index.to_s
        port[:type] = port.fetch(:type, "main").to_s
        port[:index] = index
        port[:primary] = index.zero? if primary && !port.key?(:primary)
        port[:required] = required if !required.nil? && !port.key?(:required)
        port.compact
      end
    end
  end
end
