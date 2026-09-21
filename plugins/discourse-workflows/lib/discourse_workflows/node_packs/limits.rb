# frozen_string_literal: true

module DiscourseWorkflows
  module NodePacks
    MAX_MANIFEST_BYTES = 256.kilobytes
    MAX_NODES = 20
    MAX_PROPERTIES = 40
    MAX_TEMPLATE_DEPTH = 8
    MAX_SCHEMA_BYTES = 32.kilobytes
    MAX_EXAMPLES_BYTES = 8.kilobytes
    MAX_STRING_BYTES = 16.kilobytes
    MAX_CONTAINER_ENTRIES = 1_000
    MAX_SCHEMA_ENUM_VALUES = 100
    MAX_SCHEMA_DEPTH = 12
    MAX_SCHEMA_BOUND = 1_000_000
    OUTPUT_SCHEMA_KEYS = %w[
      $schema
      type
      properties
      required
      additionalProperties
      items
      minItems
      maxItems
      minLength
      maxLength
      minimum
      maximum
      exclusiveMinimum
      exclusiveMaximum
      enum
      const
      description
    ].freeze
    OUTPUT_SCHEMA_TYPES = %w[object array string integer number boolean null].freeze

    ICONS = %w[
      list-check
      gauge
      circle-question
      table-cells
      wand-magic-sparkles
      cloud
      globe
      robot
      scale-balanced
      tags
      cubes
    ].freeze
    COLORS = %w[
      purple
      deep-orange
      orange
      grey
      indigo
      teal
      blue
      violet
      red
      pink
      green
      light-blue
      light-green
      yellow
      cyan
      brown
      salmon
    ].freeze
    METHODS = %w[GET POST PUT PATCH DELETE].freeze
    CREDENTIAL_TYPES = %w[basic_auth bearer_token header_auth].freeze
    PROPERTY_TYPES = %w[
      string
      integer
      number
      boolean
      options
      multi_options
      fixed_collection
      notice
    ].freeze
    PROPERTY_KEYS = %w[
      type
      required
      default
      min
      max
      max_items
      options
      display_options
      type_options
      ui
      label
      description
      placeholder
      no_data_expression
    ].freeze
    NESTED_PROPERTY_KEYS = (PROPERTY_KEYS - ["fixed_collection"]).freeze
    UI_KEYS = %w[control expression format show_label show_description].freeze
    TYPE_OPTION_KEYS = %w[multiple_values sortable min_required_fields max_allowed_fields].freeze
    UNSAFE_KEYS = %w[__proto__ constructor prototype].freeze
    FORBIDDEN_HEADERS = /\A(?:authorization|cookie|host|content-length|proxy-)/i

    module Limits
      MAX_MANIFEST_BYTES = NodePacks::MAX_MANIFEST_BYTES
    end
  end
end
