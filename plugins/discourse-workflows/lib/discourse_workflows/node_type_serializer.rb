# frozen_string_literal: true

module DiscourseWorkflows
  class NodeTypeSerializer
    def initialize(identifier:, available_versions:, guardian: nil)
      @identifier = identifier
      @available_versions = available_versions
      @latest_version = available_versions.last
      @guardian = guardian
    end

    def to_h
      versions = version_descriptions
      latest = versions.fetch(@latest_version)

      latest.merge(
        latest: latest,
        versions: versions,
        icon: latest.dig(:ui, :icon),
        color: latest.dig(:ui, :color),
        branching: latest.dig(:capabilities, :branching),
        manually_triggerable: latest.dig(:capabilities, :manually_triggerable),
      ).compact
    end

    private

    def version_descriptions
      @available_versions.index_with do |version|
        serializable_version(Registry.find_node_type(@identifier, version: version), version)
      end
    end

    def serializable_version(klass, version)
      properties = klass.property_schema
      webhooks = serializable_webhooks(klass)
      metadata = load_options_metadata(klass, properties)
      description =
        klass.description.merge(
          displayName: klass.label_key,
          descriptionKey: klass.description_key,
          name: @identifier,
          version: version,
          inputs: klass.input_ports,
          outputs: klass.ports,
          properties: properties,
          webhooks: webhooks,
        )

      {
        displayName: description[:displayName],
        name: @identifier,
        version: version,
        defaults: description[:defaults],
        inputs: description[:inputs],
        outputs: description[:outputs],
        properties: properties,
        credentials: description[:credentials],
        webhooks: webhooks,
        description: description,
        identifier: @identifier,
        kind: klass.kind,
        ui: klass.ui_metadata,
        capabilities: klass.capabilities,
        ports: klass.ports,
        operations: klass.operations,
        output_contracts: serializable_output_contracts(klass),
        palette_visible: klass.palette_visible?,
        available: klass.available?,
        unavailable_reason_key: (klass.unavailable_reason_key unless klass.available?),
        metadata: metadata.presence,
      }.compact
    end

    def serializable_webhooks(klass)
      klass.webhooks.map { |webhook| webhook.except(:handler) }
    end

    def serializable_output_contracts(klass)
      contracts = klass.output_contracts
      if contracts.all? { |contract|
           contract[:schema].empty? && contract[:mode] == :replace && contract[:variants].empty?
         }
        return
      end

      contracts.map { |contract| serializable_output_contract(contract) }
    end

    def serializable_output_contract(contract)
      contract.slice(:schema, :mode, :display_options).merge(
        variants:
          contract
            .fetch(:variants)
            .map { |variant| variant.slice(:schema, :mode, :display_options) },
      )
    end

    def load_options_metadata(klass, properties)
      return {} unless klass.respond_to?(:load_options_context)

      load_options_methods(properties)
        .index_with do |method_name|
          context =
            LoadOptionsContext.new(
              method_name: method_name,
              node_class: klass,
              guardian: @guardian,
              user: @guardian&.user,
            )
          klass.load_options_context(context)
        end
        .compact
    end

    def load_options_methods(properties)
      properties.values.flat_map { |definition| load_options_methods_for_field(definition) }.uniq
    end

    def load_options_methods_for_field(definition)
      return [] unless definition.is_a?(Hash)

      type_options = definition[:type_options] || definition["type_options"] || {}
      methods =
        if load_options_dependencies?(type_options)
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

      methods + nested_definitions.flat_map { |field| load_options_methods_for_field(field) }
    end

    def load_options_dependencies?(type_options)
      dependencies =
        type_options[:load_options_depends_on] || type_options["load_options_depends_on"]

      Array(dependencies).present?
    end

    def schema_field_definitions(schema)
      schema.is_a?(Hash) ? schema.values : []
    end
  end
end
