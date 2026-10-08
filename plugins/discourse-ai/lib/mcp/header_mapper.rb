# frozen_string_literal: true

module DiscourseAi
  module Mcp
    class HeaderMapper
      InvalidArgumentError = Class.new(Client::Error)

      HEADER_NAME = /\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/
      PRIMITIVE_TYPES = %w[string integer boolean].freeze
      DATA_KEYWORDS = %w[default examples const enum dependentRequired].freeze
      SCHEMA_MAP_KEYWORDS = %w[properties patternProperties dependentSchemas].freeze

      def self.request_headers(method, params, input_schema: nil)
        headers = { "Mcp-Method" => method }
        if %w[tools/call resources/read prompts/get].include?(method)
          headers["Mcp-Name"] = encode(params[:name] || params[:uri])
        end
        if method == "tools/call"
          new(input_schema).annotations.each do |name, (path, type)|
            value = argument_header(params[:arguments] || {}, path, type)
            headers["Mcp-Param-#{name}"] = value if value
          end
        end
        headers
      end

      def initialize(schema)
        @root = schema
      end

      def annotations
        unless @root.is_a?(Hash)
          raise Client::Error, I18n.t("discourse_ai.mcp_servers.errors.invalid_tool_schema")
        end

        headers = {}
        scan(@root, [], headers, [])
        headers
      end

      private

      def scan(node, path, headers, references)
        return unless node.is_a?(Hash)

        if node.key?("x-mcp-header")
          name = node["x-mcp-header"]
          unless path.present? && name.is_a?(String) && name.match?(HEADER_NAME) &&
                   PRIMITIVE_TYPES.include?(node["type"]) &&
                   !headers.keys.any? { |existing| existing.casecmp?(name) }
            raise Client::Error, I18n.t("discourse_ai.mcp_servers.errors.invalid_header_annotation")
          end
          headers[name] = [path, node["type"]]
        end

        node.each do |key, value|
          case key
          when "$ref"
            target = resolve_reference(value)
            next if target.nil?

            if references.include?(value)
              unsupported_reference! if contains_annotation?(target)
              next
            end
            scan(target, path, headers, references + [value])
          when "properties"
            if value.is_a?(Hash)
              each_schema_child(key, value) do |property, schema|
                scan(schema, path + [property], headers, references)
              end
            else
              reject_annotations!("properties" => value)
            end
          when "allOf"
            if value.is_a?(Array)
              each_schema_child(key, value) do |_property, schema|
                scan(schema, path, headers, references)
              end
            else
              reject_annotations!("allOf" => value)
            end
          when "$defs", "definitions", "x-mcp-header", *DATA_KEYWORDS
            next
          else
            reject_annotations!(key => value)
          end
        end
      end

      def resolve_reference(ref)
        unless ref.is_a?(String) && ref.start_with?("#") && !ref.match?(/%(?![0-9A-Fa-f]{2})/)
          unsupported_reference!
        end

        pointer = URI::DEFAULT_PARSER.unescape(ref.delete_prefix("#"))
        valid_pointer = pointer.valid_encoding? && (pointer.empty? || pointer.start_with?("/"))
        unsupported_reference! if !valid_pointer

        segments = pointer.empty? ? [] : pointer.split("/", -1).drop(1)
        unsupported_reference! if segments.any? { |segment| segment.match?(/~(?![01])/) }

        target =
          segments.reduce(@root) do |schema, segment|
            segment = segment.gsub("~1", "/").gsub("~0", "~")
            case schema
            when Hash
              schema[segment]
            when Array
              unsupported_reference! unless segment.match?(/\A(?:0|[1-9][0-9]*)\z/)
              index = segment.to_i
              unsupported_reference! if index >= schema.length
              schema[index]
            when NilClass
              nil
            else
              unsupported_reference!
            end
          end
        # A missing local target cannot contribute header annotations.
        return nil if target.nil?

        unsupported_reference! unless target.is_a?(Hash)
        target
      end

      def each_schema_child(key, value)
        return enum_for(:each_schema_child, key, value) unless block_given?

        if SCHEMA_MAP_KEYWORDS.include?(key) && value.is_a?(Hash)
          value.each { |property, schema| yield property, schema }
        elsif key == "allOf" && value.is_a?(Array)
          value.each { |schema| yield nil, schema }
        else
          yield nil, value
        end
      end

      def contains_annotation?(node, visited = Set.new)
        case node
        when Hash
          return false if visited.include?(node.object_id)

          visited.add(node.object_id)
          return true if node.key?("x-mcp-header")

          node.any? do |key, value|
            case key
            when "$ref"
              contains_annotation?(resolve_reference(value), visited)
            when "$defs", "definitions", *DATA_KEYWORDS
              false
            else
              each_schema_child(key, value).any? do |_property, schema|
                contains_annotation?(schema, visited)
              end
            end
          end
        when Array
          node.any? { |value| contains_annotation?(value, visited) }
        else
          false
        end
      end

      def reject_annotations!(node)
        if contains_annotation?(node)
          raise Client::Error, I18n.t("discourse_ai.mcp_servers.errors.invalid_header_annotation")
        end
      end

      def unsupported_reference!
        raise Client::Error, I18n.t("discourse_ai.mcp_servers.errors.unsupported_schema_reference")
      end

      def self.encode(value)
        if value.nil?
          raise Client::Error, I18n.t("discourse_ai.mcp_servers.errors.invalid_header_value")
        end

        value = value.to_s
        if value.ascii_only? && value.match?(/\A[\x09\x20-\x7E]*\z/) && value == value.strip &&
             !value.match?(/\A=\?base64\?.*\?=\z/)
          value
        else
          "=?base64?#{[value.encode("UTF-8")].pack("m0")}?="
        end
      end

      def self.argument_header(arguments, path, type)
        value = path.reduce(arguments.as_json) { |node, key| node.is_a?(Hash) ? node[key] : nil }
        return if value.nil?

        valid =
          case type
          when "string"
            value.is_a?(String)
          when "integer"
            value.is_a?(Integer) && value.abs <= (2**53 - 1)
          when "boolean"
            value == true || value == false
          end
        unless valid
          raise InvalidArgumentError,
                I18n.t("discourse_ai.mcp_servers.errors.invalid_annotated_argument")
        end

        encode(value)
      end
    end
  end
end
