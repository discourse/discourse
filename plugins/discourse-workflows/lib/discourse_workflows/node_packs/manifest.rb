# frozen_string_literal: true

require "uri"
require_relative "canonical_json"
require_relative "limits"

module DiscourseWorkflows
  module NodePacks
    class Manifest
      Error =
        Data.define(:path, :code, :message) do
          def as_json(*)
            { path:, code:, message: }
          end
        end
      DuplicateKeyError = Class.new(JSON::ParserError)
      StrictHash =
        Class.new(Hash) do
          def []=(key, value)
            raise DuplicateKeyError, key if key?(key)
            super
          end
        end
      Result =
        Data.define(:manifest, :definitions, :errors) do
          def valid?
            errors.empty?
          end
        end

      TOP_LEVEL_KEYS = %w[
        format
        format_version
        key
        version
        name
        description
        homepage
        icon
        color
        destinations
        credentials
        nodes
      ].freeze
      NODE_KEYS = %w[
        key
        version
        label
        subtitle
        description
        docs_url
        icon
        color
        credential
        properties
        request
        response
        examples
      ].freeze
      REQUEST_KEYS = %w[
        method
        url
        headers
        content_type
        body
        max_request_kb
        max_response_kb
        retry
      ].freeze
      RESPONSE_KEYS = %w[output output_schema].freeze
      CREDENTIAL_KEYS = %w[key label credential_types required].freeze
      DESTINATION_KEYS = %w[origin].freeze
      RETRY_KEYS = %w[max statuses].freeze
      PLACEHOLDER_KEYS = {
        "$param" => %w[$param omit_if_blank],
        "$row" => %w[$row omit_if_blank],
        "$response" => %w[$response],
        "$rows" => %w[$rows key value],
      }.freeze

      attr_reader :errors

      def self.parse(input)
        new(input).parse
      end

      def initialize(input)
        @input = input
        @errors = []
      end

      def parse
        manifest = parse_input
        return Result.new(nil, [], errors) unless manifest

        validate_structure(manifest)
        normalized = CanonicalJson.sort(manifest)
        definitions = errors.empty? ? effective_definitions(normalized) : []
        Result.new(normalized, definitions, errors)
      rescue JSON::ParserError
        add("$", "invalid_format")
        Result.new(nil, [], errors)
      rescue URI::InvalidURIError
        add("$", "invalid_format")
        Result.new(nil, [], errors)
      end

      private

      def parse_input
        value = @input
        if value.is_a?(String)
          if value.bytesize > MAX_MANIFEST_BYTES
            add("$", "too_long")
            return
          end
          value = JSON.parse(value, object_class: StrictHash)
        else
          serialized = JSON.generate(value)
          if serialized.bytesize > MAX_MANIFEST_BYTES
            add("$", "too_long")
            return
          end
          value = JSON.parse(serialized)
        end
        unless value.is_a?(Hash)
          add("$", "invalid_type")
          return
        end
        validate_resource_bounds(value)
        value
      end

      def validate_structure(manifest)
        validate_keys(manifest, TOP_LEVEL_KEYS, "$")
        require_keys(
          manifest,
          %w[format format_version key version name destinations credentials nodes],
          "$",
        )
        exact(manifest["format"], "discourse-workflows/node-pack", "format")
        exact(manifest["format_version"], 1, "format_version")
        validate_string(manifest["key"], "key", max: 32, format: /\A[a-z][a-z0-9_]{1,31}\z/)
        validate_string(
          manifest["version"],
          "version",
          max: 32,
          format: /\A\d+\.\d+\.\d+\z/,
          code: "version_format",
        )
        validate_text(manifest["name"], "name", max: 60)
        validate_text(
          manifest["description"],
          "description",
          max: 500,
          optional: true,
          multiline: true,
        )
        validate_https_url(manifest["homepage"], "homepage", optional: true)
        validate_allowlist(manifest["icon"], ICONS, "icon", "icon_not_allowed")
        validate_allowlist(manifest["color"], COLORS, "color", "color_not_allowed")
        destinations = validate_destinations(manifest["destinations"])
        credentials = validate_credentials(manifest["credentials"])
        validate_nodes(manifest["nodes"], manifest["key"], destinations, credentials)
      end

      def validate_destinations(value)
        return invalid_array("destinations") unless value.is_a?(Array)
        add("destinations", "too_many") if value.length > 5
        add("destinations", "missing_key") if value.empty?
        origins =
          value.each_with_index.filter_map do |entry, index|
            path = "destinations[#{index}]"
            unless entry.is_a?(Hash)
              add(path, "invalid_type")
              next
            end
            validate_keys(entry, DESTINATION_KEYS, path)
            require_keys(entry, %w[origin], path)
            normalize_origin(entry["origin"], "#{path}.origin")
          end
        add("destinations", "invalid_format") if origins.uniq.length != origins.length
        origins
      end

      def validate_credentials(value)
        return invalid_array("credentials") unless value.is_a?(Array)
        add("credentials", "too_many") if value.length > 3
        keys = []
        value.each_with_index do |credential, index|
          path = "credentials[#{index}]"
          unless credential.is_a?(Hash)
            add(path, "invalid_type")
            next
          end
          validate_keys(credential, CREDENTIAL_KEYS, path)
          require_keys(credential, CREDENTIAL_KEYS, path)
          validate_string(
            credential["key"],
            "#{path}.key",
            max: 40,
            format: /\A[a-z][a-z0-9_]{1,39}\z/,
          )
          validate_text(credential["label"], "#{path}.label", max: 80)
          types = credential["credential_types"]
          if types.is_a?(Array) && types.length.between?(1, 3)
            types.each do |type|
              if CREDENTIAL_TYPES.exclude?(type)
                add("#{path}.credential_types", "credential_type_unknown")
              end
            end
          else
            add("#{path}.credential_types", "invalid_type")
          end
          add("#{path}.required", "invalid_type") unless credential["required"] == true
          keys << credential["key"]
        end
        add("credentials", "invalid_format") if keys.compact.uniq.length != keys.compact.length
        value.index_by { |credential| credential.is_a?(Hash) ? credential["key"] : nil }
      end

      def validate_nodes(value, pack_key, destinations, credentials)
        return invalid_array("nodes") unless value.is_a?(Array)
        add("nodes", "missing_key") if value.empty?
        add("nodes", "too_many") if value.length > MAX_NODES
        node_keys = []
        value.each_with_index do |node, index|
          path = "nodes[#{index}]"
          unless node.is_a?(Hash)
            add(path, "invalid_type")
            next
          end
          validate_keys(node, NODE_KEYS, path)
          require_keys(node, %w[key version label properties request response], path)
          validate_string(node["key"], "#{path}.key", max: 40, format: /\A[a-z][a-z0-9_]{1,39}\z/)
          validate_string(
            node["version"],
            "#{path}.version",
            max: 16,
            format: /\A\d+\.\d+\z/,
            code: "version_format",
          )
          validate_text(node["label"], "#{path}.label", max: 80)
          validate_text(node["subtitle"], "#{path}.subtitle", max: 120, optional: true)
          validate_text(
            node["description"],
            "#{path}.description",
            max: 500,
            optional: true,
            multiline: true,
          )
          validate_https_url(node["docs_url"], "#{path}.docs_url", optional: true)
          validate_allowlist(node["icon"], ICONS, "#{path}.icon", "icon_not_allowed")
          validate_allowlist(node["color"], COLORS, "#{path}.color", "color_not_allowed")
          if node["credential"].present? && !credentials.key?(node["credential"])
            add("#{path}.credential", "credential_unknown")
          end
          validate_properties(node["properties"], "#{path}.properties")
          validate_request(
            node["request"],
            "#{path}.request",
            destinations,
            node["properties"] || {},
          )
          validate_response(node["response"], "#{path}.response", node["properties"] || {})
          validate_examples(node["examples"], "#{path}.examples", node["properties"] || {})
          identifier = "action:#{pack_key}.#{node["key"]}"
          if Registry.find_node_type(
               identifier,
               version: node["version"],
               include_disabled_plugins: true,
             )
            unless NodePackDefinition.exists?(identifier:, version: node["version"])
              add("#{path}.key", "identifier_reserved")
            end
          end
          node_keys << node["key"]
        end
        if node_keys.compact.uniq.length != node_keys.compact.length
          add("nodes", "duplicate_node_key")
        end
      end

      def validate_properties(value, path, nested: false)
        unless value.is_a?(Hash)
          add(path, "invalid_type")
          return
        end
        add(path, "too_many") if value.length > MAX_PROPERTIES
        value.each do |name, field|
          field_path = "#{path}.#{name}"
          validate_string(name, field_path, max: 80, format: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
          unless field.is_a?(Hash)
            add(field_path, "invalid_type")
            next
          end
          allowed_keys = nested ? NESTED_PROPERTY_KEYS : PROPERTY_KEYS
          validate_keys(field, allowed_keys, field_path, code: "property_key_not_allowed")
          type = field["type"]
          add("#{field_path}.type", "property_type_not_allowed") if PROPERTY_TYPES.exclude?(type)
          add(field_path, "nested_collection_forbidden") if nested && type == "fixed_collection"
          if field["default"].is_a?(String) && field["default"].start_with?("=")
            add("#{field_path}.default", "expression_default_forbidden")
          end
          expression_disabled = %w[options multi_options boolean notice].include?(type)
          if field.key?("no_data_expression") &&
               (!expression_disabled || field["no_data_expression"] != true)
            add("#{field_path}.no_data_expression", "property_key_not_allowed")
          end
          validate_text(field["label"], "#{field_path}.label", max: 80, optional: true)
          validate_text(
            field["description"],
            "#{field_path}.description",
            max: 300,
            optional: true,
            multiline: true,
          )
          validate_text(
            field["placeholder"],
            "#{field_path}.placeholder",
            max: 300,
            optional: true,
            multiline: true,
          )
          validate_property_ui(field, field_path)
          validate_property_type_options(field, field_path)
          validate_property_options(field, field_path, nested:)
        end
        normalized_schema = JSON.parse(JSON.generate(value), symbolize_names: true)
        normalize_property_enums!(normalized_schema)
        schema_errors = PropertySchemaValidator.call("node-pack", normalized_schema)
        schema_errors.each { |error| add(path, "property_key_not_allowed", error.message) }
      end

      def normalize_property_enums!(schema)
        schema.each_value do |field|
          next unless field.is_a?(Hash)
          field[:type] = field[:type]&.to_sym
          field[:ui][:control] = field[:ui][:control]&.to_sym if field[:ui].is_a?(Hash)
          Array(field[:options]).each do |option|
            if option.is_a?(Hash) && option[:values].is_a?(Hash)
              normalize_property_enums!(option[:values])
            end
          end
        end
      end

      def validate_property_ui(field, path)
        ui = field["ui"]
        return if ui.nil?
        unless ui.is_a?(Hash)
          add("#{path}.ui", "invalid_type")
          return
        end
        validate_keys(ui, UI_KEYS, "#{path}.ui", code: "property_key_not_allowed")
        if ui["control"] && !%w[textarea checkbox select].include?(ui["control"])
          add("#{path}.ui.control", "property_key_not_allowed")
        end
        if ui["format"] && (ui["format"] != "json" || field["type"] != "string")
          add("#{path}.ui.format", "invalid_format")
        end
      end

      def validate_property_type_options(field, path)
        options = field["type_options"]
        return if options.nil?
        unless options.is_a?(Hash)
          add("#{path}.type_options", "invalid_type")
          return
        end
        validate_keys(
          options,
          TYPE_OPTION_KEYS,
          "#{path}.type_options",
          code: "property_key_not_allowed",
        )
      end

      def validate_property_options(field, path, nested:)
        options = field["options"]
        return if options.nil?
        unless options.is_a?(Array) && options.length <= 255
          add("#{path}.options", "too_many")
          return
        end
        if field["type"] == "fixed_collection"
          unless options.one? && options.first.is_a?(Hash) &&
                   options.first.keys.sort == %w[name values]
            add("#{path}.options", "invalid_format")
            return
          end
          validate_text(options.first["name"], "#{path}.options[0].name", max: 80)
          validate_properties(options.first["values"], "#{path}.options[0].values", nested: true)
        elsif options.any? { |option| !valid_property_option?(option) }
          add("#{path}.options", "invalid_format")
        else
          options.each_with_index do |option, index|
            next unless option.is_a?(Hash) && option.key?("label")

            validate_text(option["label"], "#{path}.options[#{index}].label", max: 80)
          end
        end
      end

      def valid_property_option?(option)
        option.is_a?(String) ||
          (
            option.is_a?(Hash) && (option.keys - %w[value label]).empty? &&
              option["value"].is_a?(String)
          )
      end

      def validate_request(value, path, destinations, properties)
        unless value.is_a?(Hash)
          add(path, "invalid_type")
          return
        end
        validate_keys(value, REQUEST_KEYS, path)
        require_keys(value, %w[method url content_type], path)
        add("#{path}.method", "invalid_format") if METHODS.exclude?(value["method"])
        if %w[POST PUT PATCH].include?(value["method"]) && !value.key?("body")
          add("#{path}.body", "missing_key")
        end
        add("#{path}.content_type", "invalid_format") unless value["content_type"] == "json"
        origin = normalize_request_url(value["url"], "#{path}.url")
        add("#{path}.url", "url_not_in_destinations") if origin && destinations.exclude?(origin)
        headers = value["headers"] || {}
        if !headers.is_a?(Hash) || headers.length > 10
          add("#{path}.headers", "invalid_type")
        else
          headers.each do |name, header_value|
            add("#{path}.headers.#{name}", "header_forbidden") if name.match?(FORBIDDEN_HEADERS)
            validate_text(name, "#{path}.headers", max: 100)
            validate_text(header_value, "#{path}.headers.#{name}", max: 1_000)
          end
        end
        max_request = value.fetch("max_request_kb", 256)
        max_response = value.fetch("max_response_kb", 1024)
        unless max_request.is_a?(Integer) && max_request.between?(1, 1024)
          add("#{path}.max_request_kb", "invalid_format")
        end
        unless max_response.is_a?(Integer) && max_response.between?(1, 4096)
          add("#{path}.max_response_kb", "invalid_format")
        end
        validate_retry(value["retry"], "#{path}.retry")
        if value.key?("body")
          validate_template(value["body"], "#{path}.body", properties:, response: false)
        end
      end

      def validate_retry(value, path)
        return if value.nil?
        unless value.is_a?(Hash)
          add(path, "invalid_type")
          return
        end
        validate_keys(value, RETRY_KEYS, path)
        unless value.fetch("max", 0).is_a?(Integer) && value.fetch("max", 0).between?(0, 3)
          add("#{path}.max", "invalid_format")
        end
        statuses = value.fetch("statuses", [])
        unless statuses.is_a?(Array) && statuses.length <= 10 &&
                 statuses.all? { |status| status.is_a?(Integer) && status.between?(100, 599) }
          add("#{path}.statuses", "invalid_format")
        end
      end

      def validate_response(value, path, properties)
        unless value.is_a?(Hash)
          add(path, "invalid_type")
          return
        end
        validate_keys(value, RESPONSE_KEYS, path)
        if value.key?("output")
          validate_template(value["output"], "#{path}.output", properties:, response: true)
        end
        schema = value["output_schema"]
        return if schema.nil?
        if JSON.generate(schema).bytesize > MAX_SCHEMA_BYTES
          add("#{path}.output_schema", "output_schema_invalid")
          return
        end
        validate_output_schema!(schema)
        Schema.normalize(schema)
      rescue ArgumentError
        add("#{path}.output_schema", "output_schema_invalid")
      end

      def validate_examples(value, path, properties)
        return if value.nil?
        unless value.is_a?(Array) && value.length <= 5 &&
                 JSON.generate(value).bytesize <= MAX_EXAMPLES_BYTES
          add(path, "too_many")
          return
        end
        value.each_with_index do |example, index|
          unless example.is_a?(Hash) && (example.keys - %w[name parameters]).empty?
            add("#{path}[#{index}]", "unknown_key")
            next
          end
          require_keys(example, %w[name parameters], "#{path}[#{index}]")
          validate_text(example["name"], "#{path}[#{index}].name", max: 80)
          unless example["parameters"].is_a?(Hash)
            add("#{path}[#{index}].parameters", "invalid_type")
            next
          end
          if (example["parameters"].keys - properties.keys).any?
            add("#{path}[#{index}].parameters", "template_unknown_param")
          end
        end
      end

      def validate_template(value, path, properties:, response:, depth: 0, row_fields: nil)
        if depth > MAX_TEMPLATE_DEPTH
          add(path, "template_depth_exceeded")
          return
        end
        case value
        when Array
          value.each_with_index do |entry, index|
            validate_template(
              entry,
              "#{path}[#{index}]",
              properties:,
              response:,
              depth: depth + 1,
              row_fields:,
            )
          end
        when Hash
          reserved = value.keys & (PLACEHOLDER_KEYS.keys + ["$omit_if_empty"])
          placeholders = reserved - ["$omit_if_empty"]
          if placeholders.length > 1
            add(path, "template_reserved_key_misuse")
            return
          end
          if placeholders.one?
            kind = placeholders.first
            validate_keys(
              value,
              PLACEHOLDER_KEYS.fetch(kind),
              path,
              code: "template_reserved_key_misuse",
            )
            validate_placeholder(kind, value, path, properties, response, row_fields)
            if kind == "$rows"
              collection = properties[value[kind].to_s.split(".").first]
              nested_fields = collection&.dig("options", 0, "values") || {}
              validate_template(
                value["value"],
                "#{path}.value",
                properties:,
                response:,
                depth: depth + 1,
                row_fields: nested_fields,
              )
            end
          else
            value
              .except("$omit_if_empty")
              .each do |key, child|
                validate_template(
                  child,
                  "#{path}.#{key}",
                  properties:,
                  response:,
                  depth: depth + 1,
                  row_fields:,
                )
              end
          end
        end
      end

      def validate_placeholder(kind, value, path, properties, response, row_fields)
        case kind
        when "$param"
          unless properties.key?(value[kind].to_s.split(".").first)
            add(path, "template_unknown_param")
          end
        when "$rows"
          field = properties[value[kind].to_s.split(".").first]
          unless field&.fetch("type", nil) == "fixed_collection"
            add(path, "template_rows_not_collection")
          end
        when "$row"
          unless row_fields&.key?(value[kind].to_s.split(".").first)
            add(path, "template_reserved_key_misuse")
          end
        when "$response"
          add(path, "template_reserved_key_misuse") unless response
        end
      end

      def effective_definitions(manifest)
        credentials =
          manifest.fetch("credentials").index_by { |credential| credential.fetch("key") }
        manifest
          .fetch("nodes")
          .map do |node|
            effective = node.deep_dup
            apply_property_defaults!(effective.fetch("properties"))
            effective["icon"] ||= manifest["icon"]
            effective["color"] ||= manifest["color"]
            request_origin = origin_for(URI.parse(effective.dig("request", "url")))
            effective["_effective"] = {
              "approved_origins" => [request_origin],
              "credential" => credentials[node["credential"]]&.deep_dup,
            }
            effective
          end
      end

      def apply_property_defaults!(properties)
        properties.each_value do |field|
          if %w[options multi_options boolean notice].include?(field["type"])
            field["no_data_expression"] = true
          end
          Array(field["options"]).each do |option|
            if option.is_a?(Hash) && option["values"].is_a?(Hash)
              apply_property_defaults!(option["values"])
            end
          end
        end
      end

      def validate_resource_bounds(value, depth = 0)
        raise JSON::NestingError if depth > 32
        case value
        when Hash
          raise JSON::NestingError if value.length > MAX_CONTAINER_ENTRIES
          value.each do |key, child|
            add("$", "unknown_key") if UNSAFE_KEYS.include?(key.to_s)
            validate_resource_bounds(child, depth + 1)
          end
        when Array
          raise JSON::NestingError if value.length > MAX_CONTAINER_ENTRIES
          value.each { |child| validate_resource_bounds(child, depth + 1) }
        when String
          raise JSON::NestingError if value.bytesize > MAX_STRING_BYTES
        end
      rescue JSON::NestingError
        add("$", "too_many")
      end

      def validate_output_schema!(schema, depth = 0, root: true)
        raise ArgumentError unless schema.is_a?(Hash) && depth <= MAX_SCHEMA_DEPTH
        raise ArgumentError if (schema.keys - OUTPUT_SCHEMA_KEYS).any?
        raise ArgumentError unless !root || schema["type"] == "object"
        raise ArgumentError if OUTPUT_SCHEMA_TYPES.exclude?(schema["type"])
        raise ArgumentError if root && schema["$schema"] != Schema::DRAFT_URI
        raise ArgumentError if !root && schema.key?("$schema")

        validate_schema_properties!(schema, depth)
        validate_schema_items!(schema, depth)
        validate_schema_required!(schema)
        validate_schema_bounds!(schema)
        validate_schema_literals!(schema)
        raise ArgumentError if schema.key?("description") && !schema["description"].is_a?(String)
      end

      def validate_schema_properties!(schema, depth)
        properties = schema["properties"]
        if properties
          raise ArgumentError unless schema["type"] == "object" && properties.is_a?(Hash)

          properties.each_value { |child| validate_output_schema!(child, depth + 1, root: false) }
        end

        additional = schema["additionalProperties"]
        return if additional.nil? || additional == true || additional == false
        raise ArgumentError unless schema["type"] == "object"

        validate_output_schema!(additional, depth + 1, root: false)
      end

      def validate_schema_items!(schema, depth)
        return unless schema.key?("items")
        raise ArgumentError unless schema["type"] == "array"

        validate_output_schema!(schema["items"], depth + 1, root: false)
      end

      def validate_schema_required!(schema)
        required = schema["required"]
        return if required.nil?
        raise ArgumentError unless schema["type"] == "object" && required.is_a?(Array)
        raise ArgumentError if required.length > MAX_CONTAINER_ENTRIES
        raise ArgumentError unless required.all? { |name| name.is_a?(String) }
        raise ArgumentError unless required.uniq.length == required.length
        raise ArgumentError unless (required - schema.fetch("properties", {}).keys).empty?
      end

      def validate_schema_bounds!(schema)
        %w[minItems maxItems minLength maxLength].each do |key|
          next unless schema.key?(key)
          value = schema[key]
          raise ArgumentError unless value.is_a?(Integer) && value.between?(0, MAX_SCHEMA_BOUND)
        end
        %w[minimum maximum exclusiveMinimum exclusiveMaximum].each do |key|
          next unless schema.key?(key)
          raise ArgumentError unless schema[key].is_a?(Numeric)
        end
        if schema.key?("minItems") && schema.key?("maxItems") &&
             schema["minItems"] > schema["maxItems"]
          raise ArgumentError
        end
        if schema.key?("minLength") && schema.key?("maxLength") &&
             schema["minLength"] > schema["maxLength"]
          raise ArgumentError
        end
      end

      def validate_schema_literals!(schema)
        if schema.key?("enum")
          values = schema["enum"]
          unless values.is_a?(Array) && values.length.between?(1, MAX_SCHEMA_ENUM_VALUES)
            raise ArgumentError
          end
          raise ArgumentError unless values.all? { |value| schema_literal?(value) }
        end
        raise ArgumentError if schema.key?("const") && !schema_literal?(schema["const"])
      end

      def schema_literal?(value)
        value.nil? || value == true || value == false || value.is_a?(String) || value.is_a?(Numeric)
      end

      def normalize_origin(value, path)
        uri = URI.parse(value.to_s)
        unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? &&
                 uri.path.to_s.in?(["", "/"]) && uri.query.nil? && uri.fragment.nil?
          add(path, "destination_not_https")
          return
        end
        origin = origin_for(uri)
        add(path, "invalid_format") if value != origin
        origin
      rescue URI::InvalidURIError
        add(path, "destination_not_https")
        nil
      end

      def normalize_request_url(value, path)
        uri = URI.parse(value.to_s)
        unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? &&
                 !value.to_s.include?("{{") && !value.to_s.start_with?("=")
          add(path, "destination_not_https")
          return
        end
        origin_for(uri)
      rescue URI::InvalidURIError
        add(path, "invalid_format")
        nil
      end

      def origin_for(uri)
        port = uri.port == 443 ? nil : uri.port
        "https://#{uri.host.downcase}#{":#{port}" if port}"
      end

      def validate_https_url(value, path, optional: false)
        return if optional && value.nil?
        uri = URI.parse(value.to_s)
        unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
          add(path, "invalid_format")
        end
      rescue URI::InvalidURIError
        add(path, "invalid_format")
      end

      def validate_keys(value, allowed, path, code: "unknown_key")
        (value.keys - allowed).each { |key| add("#{path}.#{key}", code) }
      end

      def require_keys(value, required, path)
        (required - value.keys).each { |key| add("#{path}.#{key}", "missing_key") }
      end

      def validate_string(value, path, max:, format:, code: "invalid_format")
        return add(path, "invalid_type") unless value.is_a?(String)
        add(path, "too_long") if value.length > max
        add(path, code) unless value.match?(format)
      end

      def validate_text(value, path, max:, optional: false, multiline: false)
        return if optional && value.nil?
        return add(path, "invalid_type") unless value.is_a?(String)
        add(path, "too_long") if value.length > max
        pattern = multiline ? /[\u0000-\u0009\u000B-\u001F\u007F]/ : /[\u0000-\u001F\u007F]/
        add(path, "plain_text_required") if value.match?(pattern)
      end

      def validate_allowlist(value, allowlist, path, code)
        return if value.nil?
        add(path, code) if allowlist.exclude?(value)
      end

      def exact(value, expected, path)
        add(path, "invalid_format") unless value == expected
      end

      def invalid_array(path)
        add(path, "invalid_type")
        []
      end

      def add(path, code, message = nil)
        message ||= I18n.t("discourse_workflows.node_packs.errors.#{code}")
        errors << Error.new(path, code, message)
      end
    end
  end
end
