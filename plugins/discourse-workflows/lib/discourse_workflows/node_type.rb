# frozen_string_literal: true

module DiscourseWorkflows
  class NodeType
    include NodeErrorHandling
    extend NodeTypeDescriptor

    TOPIC_TYPE_OPTIONS = %w[all topics personal_messages].freeze

    TOPIC_TYPE_FILTER_PROPERTIES = {
      topic_type: {
        type: :options,
        required: true,
        default: "topics",
        options: TOPIC_TYPE_OPTIONS,
      },
    }.freeze

    CATEGORY_FILTER_PROPERTIES = {
      category_ids: {
        type: :array,
        required: false,
        ui: {
          control: :category,
          multiple: true,
        },
      },
      include_subcategories: {
        type: :boolean,
        required: false,
        default: true,
        ui: {
          control: :checkbox,
        },
        display_options: {
          show: {
            category_ids: [{ condition: { exists: true } }],
          },
        },
      },
    }.freeze

    TAG_FILTER_PROPERTIES = {
      tag_names: {
        type: :string,
        required: false,
        ui: {
          control: :tags,
        },
      },
    }.freeze

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
      event: nil,
      max_nodes: nil,
      capabilities: {
      },
      output_contracts: [],
      output_schema_resolver: nil,
      palette_visible: true,
      available: true,
      previewable: false,
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

    def self.previewable?
      description_value(:previewable)
    end

    def self.available?
      description_value(:available)
    end

    def self.unavailable_reason_key(configuration = nil)
      return nil unless description.key?(:unavailable_reason_key)

      description_value(:unavailable_reason_key, configuration:)
    end

    def self.inputs(configuration = {})
      description_value(:inputs, configuration:)
    end

    def self.outputs(configuration = {})
      description_value(:outputs, configuration:)
    end

    def self.properties
      description_value(:properties)
    end

    def self.credentials
      description_value(:credentials)
    end

    def self.webhooks(configuration = {})
      Array(description_value(:webhooks, configuration:)).map do |webhook|
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

      active_output_contracts(configuration).map.with_index do |candidates, index|
        resolved =
          Schema.union(
            *candidates.map do |contract|
              Schema.resolve(contract.fetch(:schema), mode: contract.fetch(:mode), input_schema:)
            end,
          )

        Schema.augment(resolved, active_output_extensions(index, configuration))
      end
    end

    def self.output_schema_resolver
      description_value(:output_schema_resolver)
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
      output_contracts.map { |contract| contract_candidates(contract, configuration) }
    end

    def self.active_output_extensions(output_index, configuration = {})
      contract = output_contracts[output_index]
      return [] if contract.nil?

      contract
        .fetch(:extensions)
        .select { |extension| Schema.visible?(extension.fetch(:display_options), configuration) }
        .map { |extension| extension.fetch(:schema) }
    end

    def self.contract_candidates(contract, configuration)
      candidates = []

      contract
        .fetch(:variants)
        .each do |variant|
          state = Schema.display_state(variant.fetch(:display_options), configuration)
          next if state == :hidden

          candidates << variant
          # Nothing after a definite match can be picked at runtime.
          return candidates if state == :visible
        end

      if Schema.visible?(contract.fetch(:display_options), configuration)
        candidates << contract.except(:variants)
      end
      # An unknown schema absorbs the union of everything it contends with, so
      # drop it rather than let it erase what the others declare.
      candidates.reject! { |candidate| unknown_contract?(candidate) }

      candidates.presence || [EMPTY_OUTPUT_CONTRACT]
    end
    private_class_method :contract_candidates

    def self.unknown_contract?(contract)
      contract.fetch(:mode) == :replace && Schema.unknown?(contract.fetch(:schema))
    end
    private_class_method :unknown_contract?

    def self.event_name
      description[:event]&.to_sym
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
        extensions:
          Array(contract[:extensions]).map do |extension|
            normalize_contract_fields(extension.deep_symbolize_keys)
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
        mode:,
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

    def self.reviewable_type_options
      Reviewable
        .types
        .uniq(&:sti_name)
        .sort_by(&:name)
        .map { |klass| { id: klass.sti_name, name: klass.name.demodulize.underscore.humanize } }
    end

    def self.trust_level_options
      TrustLevel.levels.map do |name, level|
        { value: level.to_s, label_key: "trust_levels.names.#{name}" }
      end
    end

    def self.expression_value?(value)
      Schema.expression_value?(value)
    end

    def self.validate_timezone_configuration(configuration, errors)
      timezone = (configuration || {}).deep_stringify_keys["timezone"].presence
      return if timezone.nil? || expression_value?(timezone) || WorkflowTimezone.valid?(timezone)

      errors.add(:base, I18n.t("discourse_workflows.errors.invalid_timezone", timezone: timezone))
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
      return true if category_ids.empty?

      category_ids = self.class.expand_subcategory_ids(category_ids) if include_subcategories !=
        false
      category_ids.include?(topic_category_id)
    end

    def matches_topic_type?(topic, topic_type)
      case topic_type.presence || "topics"
      when "all"
        true
      when "topics"
        !topic.private_message?
      when "personal_messages"
        topic.private_message?
      else
        false
      end
    end

    def matches_group_inbox?(topic, group_id)
      return true if group_id.blank?
      return false if !topic.private_message?

      topic.allowed_groups.exists?(id: group_id.to_i)
    end

    def matches_tags?(topic, tag_names)
      tag_names.empty? || (topic_tag_names(topic) & tag_names).any?
    end

    def topic_tag_names(topic)
      @topic_tag_names ||= {}
      @topic_tag_names[topic.id] ||= topic.tags.pluck(:name)
    end

    def resolve_timezone(exec_ctx, item_index)
      timezone = exec_ctx.get_node_parameter("timezone", item_index, default: nil).to_s.presence
      return exec_ctx.get_timezone if timezone.nil?

      if !WorkflowTimezone.valid?(timezone)
        raise_node_error!(
          I18n.t("discourse_workflows.errors.invalid_timezone", timezone: timezone),
          item_index: item_index,
        )
      end

      timezone
    end

    def matches_user_groups?(user, group_ids)
      raw_group_ids = Array.wrap(group_ids).reject(&:blank?)
      return true if raw_group_ids.empty?

      group_ids =
        raw_group_ids.filter_map do |group_id|
          value = group_id.to_s
          value.to_i if value.match?(/\A\d+\z/)
        end
      group_ids.present? && !!user&.in_any_groups?(group_ids)
    end

    def matches_reviewable_types?(reviewable, reviewable_types)
      reviewable_types = Array.wrap(reviewable_types).compact_blank
      reviewable_types.empty? || reviewable_types.include?(reviewable.class.sti_name)
    end

    def reviewable_data(reviewable)
      {
        id: reviewable.id,
        type: reviewable.type,
        status: reviewable.status,
        target_type: reviewable.target_type,
        target_id: reviewable.target_id,
        topic_id: reviewable.topic_id,
        category_id: reviewable.category_id,
        score: reviewable.score,
        created_at: reviewable.created_at&.iso8601,
      }
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
        guardian:,
        include_raw:,
        include_cooked:,
      )
    end

    def serialize_topic(topic, guardian: Discourse.system_user.guardian, custom_field_names: [])
      DiscourseWorkflows::Executor::NodeExecutionContext.serialize_topic(
        topic,
        guardian:,
        custom_field_names:,
      )
    end

    def topic_data(topic, scope: Discourse.system_user.guardian)
      serialize_record(topic, DiscourseWorkflows::TopicListItemSerializer, scope:)
    end

    def serialize_user(user, guardian: Discourse.system_user.guardian)
      DiscourseWorkflows::Executor::NodeExecutionContext.serialize_user(user, guardian:)
    end

    def with_paired_item(item, paired_item)
      Item.with_paired_item(item, paired_item)
    end
  end
end
