# frozen_string_literal: true

module DiscourseMcp
  class Primitive
    KINDS = %i[tool resource resource_template prompt].freeze
    RISKS = %i[read write destructive moderation administration external_side_effect].freeze

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
                :availability

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
      availability: nil
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
      validate!
      freeze
    end

    def available?
      availability.nil? || availability.call
    end

    def consent_relevant?
      %i[destructive moderation administration external_side_effect].include?(risk)
    end

    private

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
    rescue JSONSchemer::InvalidSchema
      raise ArgumentError, "invalid MCP primitive schema"
    end
  end
end
