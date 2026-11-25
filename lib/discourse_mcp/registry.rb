# frozen_string_literal: true

module DiscourseMcp
  class Registry
    CORE_PROVIDER = "core"
    CORE_CONTENT_NAME = /\A[a-z][a-z0-9_]*\z/
    PROVIDED_CONTENT_NAME = /\A([^:\s]+):([a-z][a-z0-9_]*)\z/

    # A kind of data that content rules can govern, such as topics or chat messages.
    #
    # `scopes` lists the OAuth scopes that only grant access to this data. When an
    # active rule denies the whole kind, the request context drops those scopes.
    ContentDataKind =
      Data.define(:name, :provider, :touched_by, :scopes) do
        def core?
          provider == CORE_PROVIDER
        end

        # Core kinds apply to every primitive. A plugin kind applies to its own
        # provider's primitives and to the ones its owner listed in `touched_by`,
        # because the owner of the data knows where it surfaces.
        def applies_to?(primitive)
          core? || provider == primitive.provider || touched_by.include?(primitive.identifier)
        end
      end

    # A kind of content rule an admin can turn on, stored as one McpContentRule row.
    ContentRuleKind =
      Data.define(
        :name,
        :provider,
        :affected_data_kinds,
        :config_schema,
        :compile,
        :admin_component_id,
        :availability,
      ) do
        def available?
          availability.nil? || availability.call
        end
      end

    def initialize
      @primitives = {}
      @content_data_kinds = {}
      @content_rule_kinds = {}
      @mutex = Mutex.new
    end

    def register(**attributes)
      primitive = Primitive.new(**attributes)
      key = [primitive.kind, primitive.identifier]
      @mutex.synchronize do
        if @primitives.key?(key)
          raise ArgumentError, "MCP primitive already registered: #{key.join(":")}"
        end

        @primitives[key] = primitive
      end
      primitive
    end

    def register_tool(identifier, **attributes)
      register(identifier: identifier, kind: :tool, **attributes)
    end

    def register_resource(identifier, **attributes)
      register(identifier: identifier, kind: :resource, **attributes)
    end

    def register_resource_template(identifier, **attributes)
      register(identifier: identifier, kind: :resource_template, **attributes)
    end

    def register_prompt(identifier, **attributes)
      register(identifier: identifier, kind: :prompt, **attributes)
    end

    def find(kind, identifier)
      @primitives[[kind.to_sym, identifier.to_s]]
    end

    def all(kind = nil)
      values = @primitives.values
      values = values.select { |primitive| primitive.kind == kind.to_sym } if kind
      values.sort_by(&:identifier)
    end

    def scopes
      all.flat_map(&:required_scopes).uniq.sort
    end

    # Registers a kind of data that content rules can govern.
    #
    # @param name [String, Symbol] An unprefixed name for core kinds, otherwise
    #   "<provider>:<name>".
    # @param provider [String] "core" or the registering plugin's name.
    # @param touched_by [Array<String>] Identifiers of other providers' primitives
    #   that surface this data.
    # @param scopes [Array<String>] OAuth scopes that only grant access to this data.
    # @returns [ContentDataKind]
    def register_content_data_kind(name, provider:, touched_by: [], scopes: [])
      name = content_name!(name, provider)
      kind =
        ContentDataKind.new(
          name:,
          provider: provider.to_s,
          touched_by: Array(touched_by).map(&:to_s).to_set.freeze,
          scopes: Array(scopes).map(&:to_s).freeze,
        )

      @mutex.synchronize do
        if @content_data_kinds.key?(name)
          raise ArgumentError, "MCP content data kind already registered: #{name}"
        end
        @content_data_kinds[name] = kind
      end
      kind
    end

    # Registers a kind of content rule.
    #
    # @param name [String, Symbol] An unprefixed name for core kinds, otherwise
    #   "<provider>:<name>".
    # @param provider [String] "core" or the registering plugin's name.
    # @param affected_data_kinds [Array<String>] Registered data kinds the rule
    #   governs. Every active rule also governs "exit_paths".
    # @param config_contract [Hash] JSON Schema the stored config must satisfy.
    # @param compile [#call] Receives the stored config and returns a
    #   ContentPolicy::Evaluator. A config that fails its contract, a compile that
    #   raises, or a result that isn't an evaluator makes the rule deny everything
    #   it governs.
    # @param admin_component_id [String, nil] Identifies the admin UI component
    #   that edits this rule.
    # @param availability [#call, nil] Returns false while the rule kind can't be
    #   enforced, for example while its plugin is disabled.
    # @returns [ContentRuleKind]
    def register_content_rule_kind(
      name,
      provider:,
      affected_data_kinds:,
      config_contract:,
      compile:,
      admin_component_id: nil,
      availability: nil
    )
      name = content_name!(name, provider)
      affected = Array(affected_data_kinds).map(&:to_s).uniq
      unknown = affected.reject { |data_kind| content_data_kind(data_kind) }
      if unknown.present?
        raise ArgumentError, "unknown MCP content data kinds: #{unknown.join(", ")}"
      end
      if !compile.respond_to?(:call)
        raise ArgumentError, "MCP content rule compile must be callable"
      end

      kind =
        ContentRuleKind.new(
          name:,
          provider: provider.to_s,
          affected_data_kinds: affected.freeze,
          config_schema: JSONSchemer.schema(config_contract.deep_stringify_keys),
          compile:,
          admin_component_id: admin_component_id&.to_s,
          availability:,
        )

      @mutex.synchronize do
        if @content_rule_kinds.key?(name)
          raise ArgumentError, "MCP content rule kind already registered: #{name}"
        end
        @content_rule_kinds[name] = kind
      end
      kind
    end

    def content_data_kind(name)
      @content_data_kinds[name.to_s]
    end

    def content_data_kinds
      @content_data_kinds.values
    end

    def content_rule_kind(name)
      @content_rule_kinds[name.to_s]
    end

    def content_rule_kinds
      @content_rule_kinds.values
    end

    private

    # Core names are unprefixed. Every other provider's names carry its own
    # prefix, so plugins can't claim core names or each other's.
    def content_name!(name, provider)
      name = name.to_s
      provider = provider.to_s
      valid =
        if provider == CORE_PROVIDER
          name.match?(CORE_CONTENT_NAME)
        else
          name.match(PROVIDED_CONTENT_NAME)&.captures&.first == provider
        end
      raise ArgumentError, "invalid MCP content kind name for #{provider}: #{name}" if !valid

      name
    end
  end
end
