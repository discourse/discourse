# frozen_string_literal: true

module DiscourseWorkflows
  # Options for properties whose choices come from `load_options_context` and don't depend
  # on other parameter values, so they can be listed before a node is configured.
  module PreloadedOptions
    def self.for(node_class, guardian: nil, properties: node_class.property_schema)
      return {} unless node_class.respond_to?(:load_options_context)

      load_options_methods(properties)
        .index_with do |method_name|
          context =
            LoadOptionsContext.new(
              method_name: method_name,
              node_class: node_class,
              guardian: guardian,
              user: guardian&.user,
            )
          node_class.load_options_context(context)
        end
        .compact
    end

    def self.load_options_methods(properties)
      properties.values.flat_map { |definition| methods_for_field(definition) }.uniq
    end

    def self.methods_for_field(definition)
      return [] unless definition.is_a?(Hash)

      type_options = definition[:type_options] || definition["type_options"] || {}
      methods =
        if depends_on_other_parameters?(type_options)
          []
        else
          Array(type_options[:load_options_method] || type_options["load_options_method"]).compact
        end

      nested_definitions = schema_field_definitions(definition[:item_schema])
      nested_definitions += schema_field_definitions(definition[:extra_item_schema])

      nested_definitions +=
        Array(definition[:options]).flat_map do |option|
          option.is_a?(Hash) && option[:values].is_a?(Hash) ? option[:values].values : []
        end

      methods + nested_definitions.flat_map { |field| methods_for_field(field) }
    end

    def self.depends_on_other_parameters?(type_options)
      dependencies =
        type_options[:load_options_depends_on] || type_options["load_options_depends_on"]

      Array(dependencies).present?
    end

    def self.schema_field_definitions(schema)
      schema.is_a?(Hash) ? schema.values : []
    end

    private_class_method :load_options_methods,
                         :methods_for_field,
                         :depends_on_other_parameters?,
                         :schema_field_definitions
  end
end
