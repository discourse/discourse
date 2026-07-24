# frozen_string_literal: true

module DiscourseWorkflows
  class NodeType
    include NodeErrorHandling
    extend NodeTypeDescriptor

    DESCRIPTION_DEFAULTS = {
      version: "1.0",
      defaults: {
      },
      inputs: [:main],
      required_inputs: nil,
      outputs: [:main],
      properties: {
      },
      credentials: [],
      webhooks: [],
      events: [],
      max_nodes: nil,
      capabilities: {
      },
      output_contracts: [],
      palette_visible: true,
      available: true,
    }.freeze

    def self.inherited(subclass)
      super
      DiscourseWorkflows::NodeType.registered_nodes << subclass
    end

    def self.registered_nodes
      @registered_nodes ||= []
    end

    def self.waiting_identifiers
      registered_nodes.select(&:waits_for_resume?).map(&:identifier)
    end

    def self.find_in(nodes)
      Array(nodes).find { |node| node["type"] == identifier }
    end

    def self.description(value = nil)
      if value
        @output_contracts = nil
        @description = DESCRIPTION_DEFAULTS.deep_merge(value.deep_symbolize_keys).freeze
      else
        @description || DESCRIPTION_DEFAULTS
      end
    end

    def self.identifier
      description.fetch(:name) { raise NotImplementedError }
    end

    def self.version
      description.fetch(:version)
    end

    def self.icon
      description.dig(:defaults, :icon)
    end

    def self.color
      description.dig(:defaults, :color)
    end

    def self.palette_visible?
      description_value(:palette_visible)
    end

    def self.available?
      description_value(:available)
    end

    def self.unavailable_reason_key(configuration = nil)
      return nil unless description.key?(:unavailable_reason_key)

      description_value(:unavailable_reason_key, configuration: configuration)
    end

    def self.inputs(configuration = {})
      description_value(:inputs, configuration: configuration)
    end

    def self.outputs(configuration = {})
      description_value(:outputs, configuration: configuration)
    end

    def self.properties
      description_value(:properties)
    end

    def self.credentials
      description_value(:credentials)
    end

    def self.webhooks(configuration = {})
      Array(description_value(:webhooks, configuration: configuration)).map do |webhook|
        webhook.deep_symbolize_keys
      end
    end

    def self.waiting_webhook_for(http_method:, path:, node_type:)
      webhooks.find do |webhook|
        webhook[:restart_webhook] == true && webhook[:node_type].to_s == node_type.to_s &&
          webhook[:http_method].to_s.casecmp?(http_method.to_s) &&
          webhook.fetch(:path) { "" }.to_s == path.to_s
      end
    end

    def self.property_schema
      properties
    end

    def self.output_schemas(configuration = {}, input_schemas: [])
      input_schema = Schema.union(*input_schemas.compact)

      active_output_contracts(configuration).map do |contract|
        Schema.resolve(
          contract.fetch(:schema),
          mode: contract.fetch(:mode),
          input_schema: input_schema,
        )
      end
    end

    def self.output_contracts
      @output_contracts ||=
        begin
          declarations = Array(description.fetch(:output_contracts))
          declarations = Array.new(ports.length) { {} } if declarations.empty?

          if declarations.length != ports.length
            raise ArgumentError,
                  "#{identifier} declares #{declarations.length} output contracts for #{ports.length} outputs"
          end

          declarations.map { |contract| normalize_output_contract(contract) }
        end
    end

    EMPTY_OUTPUT_CONTRACT = { schema: {}, mode: :replace, display_options: {} }.freeze

    def self.active_output_contracts(configuration = {})
      output_contracts.map do |contract|
        active =
          contract
            .fetch(:variants)
            .find { |variant| Schema.visible?(variant.fetch(:display_options), configuration) }
        active ||= contract.except(:variants) if Schema.visible?(
          contract.fetch(:display_options),
          configuration,
        )
        active || EMPTY_OUTPUT_CONTRACT
      end
    end

    def self.event_name
      Array(description[:events]).first
    end

    def self.manually_triggerable?
      capability_enabled?(:manually_triggerable)
    end

    def self.provides_current_user?
      capability_enabled?(:provides_current_user)
    end

    def self.waits_for_resume?
      capability_enabled?(:waits_for_resume)
    end

    def self.max_nodes
      description_value(:max_nodes)
    end

    def self.description_value(key, configuration: nil)
      value = description.fetch(key)
      return value unless value.respond_to?(:call)

      configuration.nil? ? value.call : value.call(configuration)
    end

    def self.capability_enabled?(key)
      description.dig(:capabilities, key) == true
    end

    def self.normalize_output_contract(contract)
      contract = contract.deep_symbolize_keys
      normalize_contract_fields(contract).merge(
        variants:
          Array(contract[:variants]).map do |variant|
            normalize_contract_fields(variant.deep_symbolize_keys)
          end,
      )
    end
    private_class_method :normalize_output_contract

    def self.normalize_contract_fields(contract)
      mode = contract.fetch(:mode, :replace).to_sym
      if Schema::MODES.exclude?(mode)
        raise ArgumentError, "Unknown output schema mode: #{mode.inspect}"
      end

      {
        schema: Schema.normalize(contract.fetch(:schema, {})),
        mode: mode,
        display_options: contract.fetch(:display_options, {}),
      }
    end
    private_class_method :normalize_contract_fields

    def self.normalize_tag_names(value)
      Array
        .wrap(value)
        .flat_map { |name| name.to_s.split(",") }
        .filter_map { |name| name.strip.presence }
    end

    def self.normalize_category_ids(value)
      Array.wrap(value).filter_map { |entry| entry.to_s.strip.presence&.to_i }.uniq
    end

    # TODO JOFFREY (01-2027): drop the category_id fallback once the post_migrate
    # stripping the legacy key has been promoted.
    def self.category_ids_parameter(trigger_ctx)
      value = trigger_ctx.get_node_parameter("category_ids")
      value = trigger_ctx.get_node_parameter("category_id") if value.nil?
      normalize_category_ids(value)
    end

    def self.expand_subcategory_ids(category_ids)
      category_ids.flat_map { |id| ::Category.subcategory_ids(id) }.uniq
    end

    def self.matches_category_ids?(topic_category_id, category_ids, include_subcategories: true)
      return true if category_ids.empty?

      category_ids = expand_subcategory_ids(category_ids) if include_subcategories != false
      category_ids.include?(topic_category_id)
    end

    def self.trust_level_options
      TrustLevel.levels.map do |name, level|
        { value: level.to_s, label_key: "trust_levels.names.#{name}" }
      end
    end

    def initialize(**)
    end

    def execute(exec_ctx)
      raise NotImplementedError
    end

    def trigger(trigger_ctx)
      raise NotImplementedError
    end

    def webhook(webhook_ctx)
      raise NotImplementedError
    end

    def valid?
      true
    end

    def matches?(_trigger_ctx)
      true
    end

    def output
      raise NotImplementedError
    end

    private

    def normalize_tag_names(value)
      self.class.normalize_tag_names(value)
    end

    def category_ids_parameter(trigger_ctx)
      self.class.category_ids_parameter(trigger_ctx)
    end

    def matches_category_ids?(topic_category_id, category_ids, include_subcategories: true)
      self.class.matches_category_ids?(
        topic_category_id,
        category_ids,
        include_subcategories: include_subcategories,
      )
    end

    def wrap(data, paired_item: nil)
      Item.wrap(data, paired_item:)
    end

    def serialize_record(
      record,
      serializer,
      scope: Discourse.system_user.guardian,
      root: false,
      **opts
    )
      MultiJson.load(serializer.new(record, scope:, root:, **opts).to_json).deep_symbolize_keys
    end

    def serialize_post(
      post,
      guardian: Discourse.system_user.guardian,
      include_raw: true,
      include_cooked: false
    )
      DiscourseWorkflows::Executor::NodeExecutionContext.serialize_post(
        post,
        guardian: guardian,
        include_raw: include_raw,
        include_cooked: include_cooked,
      )
    end

    def serialize_topic(topic, guardian: Discourse.system_user.guardian, custom_field_names: [])
      DiscourseWorkflows::Executor::NodeExecutionContext.serialize_topic(
        topic,
        guardian: guardian,
        custom_field_names: custom_field_names,
      )
    end

    def serialize_user(user, guardian: Discourse.system_user.guardian)
      DiscourseWorkflows::Executor::NodeExecutionContext.serialize_user(user, guardian: guardian)
    end

    def with_paired_item(item, paired_item)
      Item.with_paired_item(item, paired_item)
    end
  end
end
