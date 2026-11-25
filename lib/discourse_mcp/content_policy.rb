# frozen_string_literal: true

module DiscourseMcp
  # The site's content restrictions for one MCP request.
  #
  # Admins turn rules on by saving McpContentRule rows. Each row names a rule kind
  # registered with DiscourseMcp::Registry#register_content_rule_kind, and the
  # rule kind compiles the row's config into an Evaluator. The policy never asks
  # Guardian, so it applies to admins too: a result has to pass both Guardian and
  # this policy.
  #
  # The rows are read when the policy loads and never cached across requests, so
  # a change applies to the next request.
  class ContentPolicy
    EXIT_PATHS = "exit_paths"
    PRIVATE_MESSAGES = "private_messages"
    USABLE_LEVELS = %i[enforced untouched].freeze

    # What a rule kind's compile returns. Subclasses override the questions
    # their rule can answer; the defaults restrict nothing.
    class Evaluator
      # Whether the rule denies every record of a data kind.
      #
      # @param data_kind [String]
      # @returns [Boolean]
      def denies_all?(data_kind)
        false
      end
    end

    # Denies everything a rule governs. A rule whose config or compile can't be
    # trusted gets this evaluator, so a broken rule fails closed.
    class DenyAll < Evaluator
      def denies_all?(data_kind)
        true
      end
    end

    DENY_ALL = DenyAll.new.freeze

    Rule = Data.define(:kind, :evaluator)

    # Reads the stored rules. This is one small query, made once per request.
    #
    # @returns [ContentPolicy]
    def self.load
      new(McpContentRule.pluck(:rule_kind, :config))
    end

    # @param rows [Array<Array(String, Hash)>] Pairs of rule kind name and config.
    # @param registry [DiscourseMcp::Registry]
    def initialize(rows, registry: DiscourseMcp.registry)
      @registry = registry
      @active = rows.present?
      @orphaned = false
      @rules = []
      @usable = {}.compare_by_identity

      rows.each do |rule_kind, config|
        kind = registry.content_rule_kind(rule_kind)
        if kind.nil? || !available?(kind)
          @orphaned = true
        else
          @rules << Rule.new(kind:, evaluator: compile(kind, config))
        end
      end
    end

    # @returns [Boolean] Whether any rule is stored, recognized or not.
    def active?
      @active
    end

    # A stored rule is orphaned when its rule kind isn't registered or can't be
    # enforced right now, for example because its plugin is disabled. Nobody
    # knows what an orphaned rule governs, so only primitives declared `:none`
    # stay usable while one exists.
    #
    # @returns [Boolean]
    def orphaned?
      @orphaned
    end

    # The data kinds the active rules govern. Every active rule also governs
    # "exit_paths", the tools that send content off-site or run code the agent
    # can't see.
    #
    # @returns [Set<String>]
    def affected_data_kinds
      @affected_data_kinds ||=
        if active?
          @rules.flat_map { |rule| rule.kind.affected_data_kinds }.to_set.add(EXIT_PATHS).freeze
        else
          Set.new.freeze
        end
    end

    # Whether some rule denies every record of a data kind. An orphaned rule
    # might govern anything, so it counts as denying every kind.
    #
    # @param data_kind [String]
    # @returns [Boolean]
    def denies_all?(data_kind)
      return false if !active?
      return true if orphaned?

      @rules.any? do |rule|
        rule.kind.affected_data_kinds.include?(data_kind) && rule.evaluator.denies_all?(data_kind)
      end
    end

    # The OAuth scopes the request context drops: those that only grant access to
    # a data kind the policy denies outright.
    #
    # @returns [Set<String>]
    def revoked_scopes
      @revoked_scopes ||=
        @registry
          .content_data_kinds
          .select { |data_kind| denies_all?(data_kind.name) }
          .flat_map(&:scopes)
          .to_set
          .freeze
    end

    # The certification gate: whether a primitive's content declaration lets
    # agents use it under the active rules.
    #
    # @param primitive [DiscourseMcp::Primitive]
    # @returns [Boolean]
    def allows_primitive?(primitive)
      return true if !active?
      return @usable[primitive] if @usable.key?(primitive)

      @usable[primitive] = declaration_allows?(primitive)
    end

    private

    def declaration_allows?(primitive)
      declaration = primitive.content
      return declaration == :none if orphaned?

      case declaration
      when :none
        true
      when Hash
        !malformed?(declaration) &&
          applicable_data_kinds(primitive).all? do |data_kind|
            USABLE_LEVELS.include?(declaration[data_kind])
          end
      else
        # Undeclared and :unbounded primitives are never certified.
        false
      end
    end

    # An unprefixed name can only be a core data kind, so an unknown one is a
    # typo that would otherwise leave a kind silently undeclared. Prefixed names
    # may belong to a plugin that isn't loaded, and are ignored.
    def malformed?(declaration)
      declaration.each_key.any? do |data_kind|
        !data_kind.include?(":") && !@registry.content_data_kind(data_kind)&.core?
      end
    end

    def applicable_data_kinds(primitive)
      affected_data_kinds.select do |name|
        data_kind = @registry.content_data_kind(name)
        data_kind.nil? || data_kind.applies_to?(primitive)
      end
    end

    def available?(kind)
      kind.available?
    rescue StandardError => error
      Discourse.warn_exception(error, message: "MCP content rule availability check failed")
      false
    end

    def compile(kind, config)
      return DENY_ALL if !config.is_a?(Hash) || !kind.config_schema.valid?(config)

      evaluator = kind.compile.call(config)
      evaluator.is_a?(Evaluator) ? evaluator : DENY_ALL
    rescue StandardError => error
      Discourse.warn_exception(error, message: "MCP content rule failed to compile")
      DENY_ALL
    end
  end
end
