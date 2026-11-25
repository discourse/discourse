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
    TOPICS = "topics"
    CATEGORIES = "categories"
    TAGS = "tags"
    EMPTY_IDS = Set.new.freeze
    # Stands in for a restricted id in a filter, so the filter matches nothing,
    # exactly as it would for an id that doesn't exist.
    MISSING_ID = -1
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

      # SQL that is true for the topics the rule allows, or nil when the rule
      # doesn't narrow topics record by record.
      #
      # @param table [String] The alias of the topics table in the query.
      # @returns [String, nil]
      def topic_sql(table)
        nil
      end

      # @returns [Set<Integer>]
      def restricted_category_ids
        EMPTY_IDS
      end

      # @returns [Set<Integer>]
      def restricted_tag_ids
        EMPTY_IDS
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

    # Whether a rule narrows topics, posts, categories or tags record by record,
    # rather than only turning personal messages off.
    #
    # @returns [Boolean]
    def restricts_forum?
      return @restricts_forum if defined?(@restricts_forum)

      @restricts_forum =
        orphaned? || @rules.any? { |rule| rule.kind.affected_data_kinds.include?(TOPICS) }
    end

    # SQL that is true for the topics agents may see, or nil when nothing is
    # restricted. Topics include their posts, so a post is allowed exactly when
    # its topic is.
    #
    # @param table [String] The alias of the topics table in the query.
    # @returns [String, nil]
    def topic_condition(table = "topics")
      return if !active?
      return "FALSE" if orphaned? || denies_all?(TOPICS)

      conditions = []
      if denies_all?(PRIVATE_MESSAGES)
        conditions << "#{table}.archetype <> '#{Archetype.private_message}'"
      end
      @rules.each do |rule|
        next if rule.kind.affected_data_kinds.exclude?(TOPICS)
        conditions << rule.evaluator.topic_sql(table)
      end
      conditions.compact!
      conditions.map { |condition| "(#{condition})" }.join(" AND ").presence
    end

    # @param relation [ActiveRecord::Relation<Topic>] A relation on the topics table.
    # @returns [ActiveRecord::Relation<Topic>]
    def scope_topics(relation)
      condition = topic_condition("topics")
      condition ? relation.where(condition) : relation
    end

    # @param relation [ActiveRecord::Relation<Post>] A relation on the posts table.
    # @returns [ActiveRecord::Relation<Post>]
    def scope_posts(relation, column: "posts.topic_id")
      condition = topic_condition("mcp_policy_topics")
      return relation if !condition

      relation.where(<<~SQL.squish)
        EXISTS (
          SELECT 1 FROM topics mcp_policy_topics
          WHERE mcp_policy_topics.id = #{column} AND #{condition}
        )
      SQL
    end

    # Whether agents may see the topic with this id, judged on the topic as
    # stored now. Deleted topics are judged like live ones; a missing topic is
    # never allowed.
    #
    # @param topic_id [Integer, nil]
    # @returns [Boolean]
    def allows_topic_id?(topic_id)
      return true if !active?
      return false if topic_id.blank?

      allowed_topic_ids([topic_id]).include?(topic_id.to_i)
    end

    # The ids among the given ones of topics agents may see, in one query.
    #
    # @param topic_ids [Array<Integer>]
    # @returns [Set<Integer>]
    def allowed_topic_ids(topic_ids)
      topic_ids = topic_ids.compact.map(&:to_i).uniq
      return topic_ids.to_set if !active?
      return Set.new if topic_ids.empty?

      condition = topic_condition("topics") || "TRUE"
      DB.query_single(
        "SELECT id FROM topics WHERE id IN (:topic_ids) AND #{condition}",
        topic_ids:,
      ).to_set
    end

    # @param topic [Topic, nil]
    # @returns [Boolean]
    def allows_topic?(topic)
      topic.present? && allows_topic_id?(topic.id)
    end

    # @param post [Post, nil]
    # @returns [Boolean]
    def allows_post?(post)
      post.present? && allows_topic_id?(post.topic_id)
    end

    # @returns [Set<Integer>]
    def restricted_category_ids
      @restricted_category_ids ||=
        if !restricts_forum?
          EMPTY_IDS
        elsif orphaned? || denies_all?(CATEGORIES)
          Category.pluck(:id).to_set.freeze
        else
          @rules.flat_map { |rule| rule.evaluator.restricted_category_ids.to_a }.to_set.freeze
        end
    end

    # @param category_id [Integer, nil]
    # @returns [Boolean] False for a restricted category; true for none at all.
    def allows_category_id?(category_id)
      category_id.blank? || restricted_category_ids.exclude?(category_id.to_i)
    end

    # @param relation [ActiveRecord::Relation<Category>]
    # @returns [ActiveRecord::Relation<Category>]
    def scope_categories(relation)
      ids = restricted_category_ids
      ids.empty? ? relation : relation.where.not(id: ids.to_a)
    end

    # @param category_id [Integer, nil]
    # @returns [Integer, nil] The id, or nil when the category is restricted.
    def redact_category_id(category_id)
      allows_category_id?(category_id) ? category_id : nil
    end

    # @returns [Set<Integer>]
    def restricted_tag_ids
      @restricted_tag_ids ||=
        if !restricts_forum?
          EMPTY_IDS
        elsif orphaned? || denies_all?(TAGS)
          Tag.pluck(:id).to_set.freeze
        else
          @rules.flat_map { |rule| rule.evaluator.restricted_tag_ids.to_a }.to_set.freeze
        end
    end

    # @param relation [ActiveRecord::Relation<Tag>]
    # @returns [ActiveRecord::Relation<Tag>]
    def scope_tags(relation)
      ids = restricted_tag_ids
      ids.empty? ? relation : relation.where.not(id: ids.to_a)
    end

    # @returns [Set<String>] Names of the restricted tags.
    def restricted_tag_names
      @restricted_tag_names ||=
        if restricted_tag_ids.empty?
          Set.new.freeze
        else
          Tag.where(id: restricted_tag_ids.to_a).pluck(:name).to_set.freeze
        end
    end

    # Serialized tags (hashes with an `id` or a `name`) are accepted too. A
    # hash that carries neither can't be checked, so it isn't allowed.
    #
    # @param tag [Tag, Hash, String] A tag, a serialized tag or a tag name.
    # @returns [Boolean]
    def allows_tag?(tag)
      return restricted_tag_ids.exclude?(tag.id) if tag.is_a?(Tag)

      if tag.is_a?(Hash)
        tag = tag.with_indifferent_access
        return false if tag[:id].blank? && tag[:name].blank?
        return false if tag[:id].present? && restricted_tag_ids.include?(tag[:id].to_i)
        return tag[:name].blank? || allows_tag?(tag[:name].to_s)
      end

      restricted_tag_names.none? { |name| name.casecmp?(tag.to_s) }
    end

    # Checks a tool's structured result on its way out, as a backstop behind the
    # tool's own narrowing. Ids of restricted categories and tags are redacted,
    # because an allowed topic may sit in a restricted category. A topic or post
    # id of a restricted topic means the tool leaked, so the whole result is
    # refused and the leak is reported.
    #
    # @param result [Hash] The tool's result, with `structuredContent` and `content`.
    # @param identifier [String] The tool, for the report.
    # @returns [Hash] The result, redacted.
    def filter_tool_result(result, identifier:)
      structured = result[:structuredContent]
      return result if !active? || !structured.is_a?(Hash)

      topic_ids = Set.new
      post_ids = Set.new
      collect_ids(structured, topic_ids, post_ids)
      if (leaked = restricted_topic_ids(topic_ids, post_ids)).present?
        Discourse.warn_exception(
          StandardError.new("MCP content policy tripwire"),
          message: "MCP tool #{identifier} returned restricted topics #{leaked.join(",")}",
        )
        raise ToolError, I18n.t("mcp.errors.content_policy_output_blocked")
      end
      return result if restricted_category_ids.empty? && restricted_tag_ids.empty?

      redacted = redact_category_ids(structured)
      return result if redacted == structured

      text = JSON.generate(structured)
      content =
        Array(result[:content]).map do |item|
          if item.is_a?(Hash) && item[:type] == "text" && item[:text] == text
            item.merge(text: JSON.generate(redacted))
          else
            item
          end
        end
      result.merge(structuredContent: redacted, content:)
    end

    # Raises the generic refusal unless no rule restricts the given data kinds.
    # Tools call it before a branch whose output the policy can't narrow.
    #
    # @param data_kinds [Array<String>] Data kinds the branch exposes; all
    #   forum kinds when omitted.
    def require_unrestricted!(*data_kinds)
      data_kinds = [TOPICS, PRIVATE_MESSAGES, CATEGORIES, TAGS] if data_kinds.empty?
      governed = data_kinds.map(&:to_s) & affected_data_kinds.to_a
      raise ToolError, I18n.t("mcp.errors.content_policy_blocked") if governed.present?
    end

    private

    TOPIC_ID_KEYS = %w[topic_id topic_ids].freeze
    POST_ID_KEYS = %w[post_id post_ids].freeze
    CATEGORY_ID_KEYS = %w[category_id parent_category_id].freeze
    CATEGORY_IDS_KEYS = %w[category_ids].freeze
    TAG_IDS_KEYS = %w[tag_ids].freeze

    def collect_ids(value, topic_ids, post_ids)
      case value
      when Hash
        value.each do |key, child|
          key = key.to_s
          if TOPIC_ID_KEYS.include?(key)
            topic_ids.merge(Array(child).grep(Integer))
          elsif POST_ID_KEYS.include?(key)
            post_ids.merge(Array(child).grep(Integer))
          else
            collect_ids(child, topic_ids, post_ids)
          end
        end
      when Array
        value.each { |child| collect_ids(child, topic_ids, post_ids) }
      end
    end

    # Ids of existing topics the policy restricts among the named ones and
    # the topics of the named posts. Ids of records that no longer exist pass.
    def restricted_topic_ids(topic_ids, post_ids)
      return [] if topic_ids.empty? && post_ids.empty?

      topic_ids = topic_ids.to_a
      if post_ids.present?
        topic_ids |= Post.with_deleted.where(id: post_ids.to_a).distinct.pluck(:topic_id)
      end
      condition = topic_condition("topics")
      return [] if topic_ids.empty? || condition.nil?

      DB.query_single(
        "SELECT id FROM topics WHERE id IN (:topic_ids) AND NOT (#{condition})",
        topic_ids:,
      )
    end

    def redact_category_ids(value)
      case value
      when Hash
        value.to_h do |key, child|
          name = key.to_s
          if CATEGORY_ID_KEYS.include?(name) && child.is_a?(Integer)
            [key, redact_category_id(child)]
          elsif CATEGORY_IDS_KEYS.include?(name) && child.is_a?(Array)
            [key, child.select { |id| !id.is_a?(Integer) || allows_category_id?(id) }]
          elsif TAG_IDS_KEYS.include?(name) && child.is_a?(Array)
            [key, child.select { |id| !id.is_a?(Integer) || restricted_tag_ids.exclude?(id) }]
          else
            [key, redact_category_ids(child)]
          end
        end
      when Array
        value.map { |child| redact_category_ids(child) }
      else
        value
      end
    end

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
