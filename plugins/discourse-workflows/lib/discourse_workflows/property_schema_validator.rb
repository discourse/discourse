# frozen_string_literal: true

module DiscourseWorkflows
  class PropertySchemaValidator
    KNOWN_FIELD_TYPES = %i[
      string
      integer
      number
      float
      boolean
      options
      multi_options
      collection
      fixed_collection
      assignment_collection
      array
      object
      notice
      credential
      icon
      custom
    ].freeze

    KNOWN_FIELD_KEYS = %i[
      type
      required
      default
      options
      min
      max
      max_items
      validate
      no_data_expression
      display_options
      item_schema
      extra_item_schema
      type_options
      ui
      control_options
    ].freeze

    TYPE_SPECIFIC_KEYS = { credential: %i[credential_type] }.freeze

    KNOWN_TYPE_OPTIONS_KEYS = %i[
      add_optional_field_button_text
      assignment_types
      hide_optional_fields
      item_title
      layout
      load_options_depends_on
      load_options_method
      max_allowed_fields
      min_required_fields
      multiple_values
      sortable
    ].freeze

    KNOWN_UI_KEYS = %i[
      control
      dynamic_value
      expression
      filter
      flat
      format
      hidden
      multiple
      show_description
      show_label
      singular_name
    ].freeze

    KNOWN_CONTROL_OPTIONS_KEYS = %i[
      action_icon
      action_label
      action_route
      action_route_models
      filterable
      height
      lang
      name_property
      none
      none_label_field
      none_label_i18n_key
      option_format
      set_from_option
      resets
      value_property
    ].freeze

    KNOWN_UI_CONTROLS = %i[
      actor
      boolean
      category
      checkbox
      code
      combo_box
      condition_builder
      credential
      data_table_column_select
      data_table_columns
      data_table_condition_builder
      data_table_select
      filter_query
      group_select
      icon
      multi_combo_box
      multi_input
      notice
      password
      query_params
      select
      tags
      textarea
      url_preview
      user
      user_seen_trigger_options
      user_or_group
    ].freeze

    TYPES_REQUIRING_OPTIONS = %i[options multi_options collection fixed_collection].freeze

    Error =
      Struct.new(:node, :path, :message) do
        def to_s
          "#{node} at #{path.map(&:to_s).join(".")}: #{message}"
        end
      end

    def self.validate_all
      DiscourseWorkflows::NodeType
        .registered_nodes
        .flat_map { |node_class| validate_node(node_class) }
        .compact
    end

    def self.validate_node(node_class)
      identifier =
        begin
          node_class.identifier
        rescue NotImplementedError
          return []
        end
      call(identifier, node_class.property_schema)
    end

    def self.call(identifier, schema)
      new(identifier, schema).validate
    end

    def initialize(identifier, schema)
      @identifier = identifier
      @schema = schema
      @errors = []
    end

    def validate
      if @schema.is_a?(Hash)
        validate_schema(@schema, path: [])
      else
        add_error([], "property_schema must be a Hash, got #{@schema.class}")
      end
      @errors
    end

    private

    def validate_schema(schema, path:)
      validate_schema_with_siblings(schema, path: path, siblings: schema.keys)
    end

    def validate_field(name, field, path:, sibling_keys:)
      field_path = path + [name]

      unless field.is_a?(Hash)
        add_error(field_path, "expected field definition Hash, got #{field.class}")
        return
      end

      validate_field_keys(field, path: field_path)
      validate_field_type(field, path: field_path)
      validate_field_options(field, path: field_path)
      validate_ui(field, path: field_path)
      validate_type_options(field, path: field_path)
      validate_control_options(field, path: field_path)
      validate_visibility(field, path: field_path, sibling_keys: sibling_keys)
      validate_item_schemas(field, path: field_path)
      validate_collection_options(field, path: field_path)
    end

    def validate_field_keys(field, path:)
      allowed = KNOWN_FIELD_KEYS + TYPE_SPECIFIC_KEYS.fetch(field[:type], [])
      unknown = field.keys - allowed
      return if unknown.empty?
      add_error(path, "unknown field key(s): #{unknown.sort.inspect}")
    end

    def validate_field_type(field, path:)
      return if KNOWN_FIELD_TYPES.include?(field[:type])
      add_error(path + [:type], "unknown type: #{field[:type].inspect}")
    end

    def validate_field_options(field, path:)
      type = field[:type]
      return if TYPES_REQUIRING_OPTIONS.exclude?(type)
      return if field.dig(:type_options, :load_options_method)

      options = field[:options]
      return if options.is_a?(Array) && options.any?
      add_error(path, "type #{type.inspect} requires a non-empty :options array")
    end

    def validate_ui(field, path:)
      ui = field[:ui]
      return if ui.nil?

      ui_path = path + [:ui]

      unless ui.is_a?(Hash)
        add_error(ui_path, "expected Hash, got #{ui.class}")
        return
      end

      unknown = ui.keys - KNOWN_UI_KEYS
      add_error(ui_path, "unknown ui key(s): #{unknown.sort.inspect}") if unknown.any?

      control = ui[:control]
      return if control.nil? || KNOWN_UI_CONTROLS.include?(control)
      add_error(ui_path + [:control], "unknown control: #{control.inspect}")
    end

    def validate_type_options(field, path:)
      options = field[:type_options]
      return if options.nil?

      options_path = path + [:type_options]

      unless options.is_a?(Hash)
        add_error(options_path, "expected Hash, got #{options.class}")
        return
      end

      unknown = options.keys - KNOWN_TYPE_OPTIONS_KEYS
      return if unknown.empty?
      add_error(options_path, "unknown type_options key(s): #{unknown.sort.inspect}")
    end

    def validate_control_options(field, path:)
      options = field[:control_options]
      return if options.nil?

      options_path = path + [:control_options]

      unless options.is_a?(Hash)
        add_error(options_path, "expected Hash, got #{options.class}")
        return
      end

      unknown = options.keys - KNOWN_CONTROL_OPTIONS_KEYS
      return if unknown.empty?
      add_error(options_path, "unknown control_options key(s): #{unknown.sort.inspect}")
    end

    def validate_visibility(field, path:, sibling_keys:)
      display_options = field[:display_options]
      return if display_options.nil?

      display_options_path = path + [:display_options]
      unless display_options.is_a?(Hash)
        add_error(display_options_path, "expected Hash, got #{display_options.class}")
        return
      end

      unknown = display_options.keys - %i[show hide]
      if unknown.any?
        add_error(display_options_path, "unknown display_options key(s): #{unknown.sort.inspect}")
      end

      %i[show hide].each do |key|
        rules = display_options[key]
        next if rules.nil?

        rule_path = display_options_path + [key]
        unless rules.is_a?(Hash)
          add_error(rule_path, "expected Hash, got #{rules.class}")
          next
        end

        rules.each do |ref, expected|
          if sibling_keys.exclude?(ref)
            add_error(rule_path, "references unknown sibling field: #{ref.inspect}")
          end

          next if expected.is_a?(Array)
          add_error(rule_path + [ref], "expected Array, got #{expected.class}")
        end
      end
    end

    def validate_item_schemas(field, path:)
      item_schema = field[:item_schema]

      validate_schema(item_schema, path: path + [:item_schema]) if item_schema.is_a?(Hash)

      extra = field[:extra_item_schema]
      return unless extra.is_a?(Hash)

      # Extra item fields are rendered inside the same row as item_schema fields,
      # so visibility rules may reference either side.
      extra_siblings = (item_schema.is_a?(Hash) ? item_schema.keys : []) + extra.keys
      validate_schema_with_siblings(
        extra,
        path: path + [:extra_item_schema],
        siblings: extra_siblings,
      )
    end

    def validate_collection_options(field, path:)
      case field[:type]
      when :collection
        validate_option_bag_options(field[:options], path: path + [:options])
      when :fixed_collection
        validate_fixed_collection_options(field[:options], path: path + [:options])
      end
    end

    def validate_option_bag_options(options, path:)
      return unless options.is_a?(Array)

      siblings = options.filter_map { |option| option[:name]&.to_sym if option.is_a?(Hash) }
      options.each_with_index do |option, index|
        option_path = path + [index]
        unless option.is_a?(Hash)
          add_error(option_path, "expected option definition Hash, got #{option.class}")
          next
        end

        name = option[:name]
        if name.blank?
          add_error(option_path, "collection option requires :name")
          next
        end

        option_field = option.except(:name, :display_name)
        validate_field(name.to_sym, option_field, path: path, sibling_keys: siblings)
      end
    end

    def validate_fixed_collection_options(options, path:)
      return unless options.is_a?(Array)

      options.each_with_index do |group, index|
        group_path = path + [index]
        unless group.is_a?(Hash)
          add_error(group_path, "expected fixed collection group Hash, got #{group.class}")
          next
        end

        unknown = group.keys - %i[name display_name values]
        if unknown.any?
          add_error(group_path, "unknown fixed collection group key(s): #{unknown.sort.inspect}")
        end

        add_error(group_path, "fixed collection group requires :name") if group[:name].blank?
        values = group[:values]
        unless values.is_a?(Hash)
          add_error(group_path + [:values], "expected Hash, got #{values.class}")
          next
        end

        validate_schema(values, path: group_path + [:values])
      end
    end

    def validate_schema_with_siblings(schema, path:, siblings:)
      schema.each { |name, field| validate_field(name, field, path: path, sibling_keys: siblings) }
    end

    def add_error(path, message)
      @errors << Error.new(@identifier, path, message)
    end
  end
end
