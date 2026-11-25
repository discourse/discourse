# frozen_string_literal: true

module DiscourseMcp
  class Primitive
    KINDS = %i[tool resource resource_template prompt].freeze
    RISKS = %i[read write destructive moderation administration external_side_effect].freeze
    CONTENT_LEVELS = %i[enforced untouched unenforced].freeze
    CONTENT_DATA_KIND = /\A(?:[a-z0-9][a-z0-9_-]*:)?[a-z][a-z0-9_]*\z/

    attr_reader :identifier,
                :kind,
                :title,
                :description,
                :input_schema,
                :output_schema,
                :required_scopes,
                :annotations,
                :risk,
                :provider,
                :implementation,
                :availability,
                :content

    # @param content [nil, Symbol, Hash] What governed data the primitive touches,
    #   read by the content policy gate. `nil` is undeclared and blocked while any
    #   content rule is active. `:none` touches no governed data, now or later.
    #   `:unbounded` has unrestricted data access, such as arbitrary SQL, and is
    #   blocked while any rule is active. A Hash maps each data kind name to
    #   `:enforced` (the primitive applies the policy to it), `:untouched` (it
    #   never surfaces that data) or `:unenforced` (it surfaces that data without
    #   applying the policy, so rules governing that kind block it).
    def initialize(
      identifier:,
      kind:,
      title:,
      description:,
      implementation:,
      input_schema: { type: "object", additionalProperties: false },
      output_schema: nil,
      required_scopes: [],
      annotations: {},
      risk: :read,
      provider: :core,
      availability: nil,
      defer: false,
      content: nil
    )
      @identifier = identifier.to_s
      @kind = kind.to_sym
      @title = title
      @description = description
      @implementation = implementation
      @input_schema = input_schema.deep_stringify_keys
      @output_schema = output_schema&.deep_stringify_keys
      @required_scopes = Array(required_scopes).map(&:to_s).freeze
      @annotations = annotations.deep_stringify_keys.freeze
      @risk = risk.to_sym
      @provider = provider.to_s
      @availability = availability
      @defer = defer
      @content = normalize_content(content)
      validate!
      freeze
    end

    def available?
      availability.nil? || availability.call
    end

    def deferred?
      @defer
    end

    def consent_relevant?
      %i[destructive moderation administration external_side_effect].include?(risk)
    end

    private

    # Only the declaration's shape is checked here. Whether its keys name
    # registered data kinds is up to the gate, because plugins can register
    # their data kinds after the primitives that mention them.
    def normalize_content(content)
      return content if content.nil? || content == :none || content == :unbounded
      raise ArgumentError, "invalid MCP primitive content declaration" if !content.is_a?(Hash)

      content
        .each_with_object({}) do |(data_kind, level), normalized|
          if !(data_kind.is_a?(String) || data_kind.is_a?(Symbol)) ||
               !data_kind.to_s.match?(CONTENT_DATA_KIND)
            raise ArgumentError, "invalid MCP primitive content data kind"
          end
          level = level.to_sym if level.is_a?(String) || level.is_a?(Symbol)
          if !CONTENT_LEVELS.include?(level)
            raise ArgumentError, "invalid MCP primitive content level"
          end
          if normalized.key?(data_kind.to_s)
            raise ArgumentError, "duplicate MCP primitive content data kind"
          end

          normalized[data_kind.to_s] = level
        end
        .freeze
    end

    def validate!
      raise ArgumentError, "invalid MCP primitive kind" if !KINDS.include?(kind)
      raise ArgumentError, "invalid MCP primitive risk" if !RISKS.include?(risk)
      if !identifier.match?(/\A[A-Za-z0-9_.-]{1,128}\z/)
        raise ArgumentError, "invalid MCP primitive identifier"
      end
      raise ArgumentError, "MCP primitive title is required" if title.blank?
      raise ArgumentError, "MCP primitive description is required" if description.blank?
      raise ArgumentError, "MCP primitive implementation is required" if implementation.blank?
      if kind == :tool && input_schema["type"] != "object"
        raise ArgumentError, "MCP tool input schema must describe an object"
      end
      JSONSchemer.schema(input_schema)
      JSONSchemer.schema(output_schema) if output_schema
      if required_scopes.any? { |scope| !scope.match?(/\A[a-z0-9][a-z0-9:_-]{0,127}\z/) }
        raise ArgumentError, "invalid MCP primitive scope"
      end
      allowed_annotations = %w[title readOnlyHint destructiveHint idempotentHint openWorldHint]
      if (annotations.keys - allowed_annotations).present? ||
           annotations.except("title").values.any? { |value| value != true && value != false }
        raise ArgumentError, "invalid MCP primitive annotations"
      end
    end
  end
end
