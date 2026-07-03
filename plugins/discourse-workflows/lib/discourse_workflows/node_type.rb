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

    def self.normalize_tag_names(value)
      Array
        .wrap(value)
        .flat_map { |name| name.to_s.split(",") }
        .filter_map { |name| name.strip.presence }
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
