# frozen_string_literal: true

module DiscourseWorkflows
  class PropertySchemaValidator
    KNOWN_FIELD_TYPES = %i[
      string
      integer
      boolean
      options
      multi_options
      collection
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
      options_source
      min
      max
      max_items
      validate
      visible_if
      visible_unless
      item_schema
      extra_item_schema
      ui
      control_options
    ].freeze

    TYPE_SPECIFIC_KEYS = { credential: %i[credential_type] }.freeze

    KNOWN_UI_KEYS = %i[
      control
      expression
      flat
      format
      hidden
      show_description
      show_label
      singular_name
    ].freeze

    KNOWN_CONTROL_OPTIONS_KEYS = %i[
      filterable
      height
      lang
      name_property
      none
      option_format
      patch_from_option
      resets
      value_property
    ].freeze

    KNOWN_UI_CONTROLS = %i[
      boolean
      category
      code
      combo_box
      condition_builder
      credential
      data_table_column_select
      data_table_columns
      data_table_condition_builder
      filter_query
      icon
      multi_combo_box
      notice
      password
      query_params
      select
      tags
      textarea
      url_preview
      user
      user_or_group
    ].freeze

    TYPES_REQUIRING_OPTIONS = %i[options multi_options].freeze

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
      sibling_keys = schema.keys
      schema.each do |name, field|
        validate_field(name, field, path: path, sibling_keys: sibling_keys)
      end
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
      validate_control_options(field, path: field_path)
      validate_visibility(field, path: field_path, sibling_keys: sibling_keys)
      validate_item_schemas(field, path: field_path)
    end

    def validate_field_keys(field, path:)
      allowed = KNOWN_FIELD_KEYS + TYPE_SPECIFIC_KEYS.fetch(field[:type], [])
      unknown = field.keys - allowed
      return if unknown.empty?
      add_error(path, "unknown field key(s): #{unknown.sort.inspect}")
    end

    def validate_field_type(field, path:)
      type = field[:type]
      return if KNOWN_FIELD_TYPES.include?(type)
      add_error(path + [:type], "unknown type: #{type.inspect}")
    end

    def validate_field_options(field, path:)
      type = field[:type]
      return if TYPES_REQUIRING_OPTIONS.exclude?(type)

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
      %i[visible_if visible_unless].each do |key|
        rules = field[key]
        next if rules.nil?

        rule_path = path + [key]
        unless rules.is_a?(Hash)
          add_error(rule_path, "expected Hash, got #{rules.class}")
          next
        end

        rules.each_key do |ref|
          next if sibling_keys.include?(ref)
          add_error(rule_path, "references unknown sibling field: #{ref.inspect}")
        end
      end
    end

    def validate_item_schemas(field, path:)
      type = field[:type]
      item_schema = field[:item_schema]

      if type == :collection && item_schema.nil?
        add_error(path, "type :collection requires :item_schema")
      end

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

    def validate_schema_with_siblings(schema, path:, siblings:)
      schema.each { |name, field| validate_field(name, field, path: path, sibling_keys: siblings) }
    end

    def add_error(path, message)
      @errors << Error.new(@identifier, path, message)
    end
  end
end
