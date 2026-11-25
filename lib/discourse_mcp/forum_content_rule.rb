# frozen_string_literal: true

module DiscourseMcp
  # The rule that keeps topics and posts in chosen categories or with chosen tags
  # away from agents.
  #
  # A regular topic is allowed when it passes the allowlist (every topic in "all"
  # mode; in "selected" mode, a topic in an allowed category's subtree or with an
  # allowed tag) and matches nothing denied (no denied category's subtree, no
  # denied tag). Personal messages have no category, so only denied tags apply to
  # them.
  class ForumContentRule < ContentPolicy::Evaluator
    NAME = "forum_content"
    ALLOW_ALL = "all"
    ALLOW_SELECTED = "selected"

    ID_LIST = { type: "array", items: { type: "integer" }, uniqueItems: true }.freeze

    CONFIG_CONTRACT = {
      type: "object",
      additionalProperties: false,
      required: %w[allow deny],
      properties: {
        allow: {
          type: "object",
          additionalProperties: false,
          required: %w[mode category_ids tag_ids],
          properties: {
            mode: {
              enum: [ALLOW_ALL, ALLOW_SELECTED],
            },
            category_ids: ID_LIST,
            tag_ids: ID_LIST,
          },
        },
        deny: {
          type: "object",
          additionalProperties: false,
          required: %w[category_ids tag_ids],
          properties: {
            category_ids: ID_LIST,
            tag_ids: ID_LIST,
          },
        },
      },
    }.freeze

    # Category ids of the given categories and all their descendants. Nesting
    # depth isn't capped and nothing is cached, so a category moved since the
    # rule was saved is covered on the next request.
    SUBTREE_SQL = <<~SQL
      WITH RECURSIVE subtree(id) AS (
        SELECT id FROM categories WHERE id IN (:ids)
        UNION
        SELECT categories.id FROM categories JOIN subtree ON categories.parent_category_id = subtree.id
      )
      SELECT id FROM subtree
    SQL

    # @param config [Hash] A config that satisfies CONFIG_CONTRACT.
    # @returns [ForumContentRule]
    def self.compile(config)
      new(config.deep_stringify_keys)
    end

    def initialize(config)
      allow = config.fetch("allow")
      deny = config.fetch("deny")
      @selected = allow.fetch("mode") == ALLOW_SELECTED
      @allowed_category_ids = subtree(allow.fetch("category_ids"))
      @allowed_tag_ids = allow.fetch("tag_ids").to_set.freeze
      @denied_category_ids = subtree(deny.fetch("category_ids"))
      @denied_tag_ids = with_synonyms(deny.fetch("tag_ids"))
    end

    # SQL that is true for the topics this rule allows.
    #
    # @param table [String] The alias of the topics table in the query.
    # @returns [String]
    def topic_sql(table)
      regular = [category_sql(table)]
      if @selected
        allowed_category = in_sql("#{table}.category_id", @allowed_category_ids)
        regular << "(#{allowed_category} OR #{tagged_sql(table, @allowed_tag_ids)})"
      end

      <<~SQL.squish
        (#{table}.archetype = '#{Archetype.private_message}' OR (#{regular.join(" AND ")}))
        AND NOT #{tagged_sql(table, @denied_tag_ids)}
      SQL
    end

    # @param category_id [Integer]
    # @param tag_ids [Set<Integer>] The topic's complete effective tags.
    # @param private_message [Boolean]
    # @returns [Boolean]
    def allows_prospective_topic?(category_id:, tag_ids:, private_message:)
      return false if tag_ids.intersect?(@denied_tag_ids)
      return true if private_message
      return false if @denied_category_ids.include?(category_id)
      return true if !@selected

      @allowed_category_ids.include?(category_id) || tag_ids.intersect?(@allowed_tag_ids)
    end

    # A category is restricted when it lies in a denied subtree, when the
    # allowlist is selective and the category is outside every allowed subtree,
    # or when its definition topic carries a denied tag. A restricted category's
    # name, description and settings are hidden like its topics.
    #
    # @returns [Set<Integer>]
    def restricted_category_ids
      @restricted_category_ids ||=
        begin
          ids = @denied_category_ids.dup
          if @selected
            # A selective allowlist whose categories no longer exist allows none.
            allowed = @allowed_category_ids.to_a.presence || [-1]
            ids.merge(
              DB.query_single("SELECT id FROM categories WHERE id NOT IN (:allowed)", allowed:),
            )
          end
          if @denied_tag_ids.present?
            ids.merge(DB.query_single(<<~SQL, tag_ids: @denied_tag_ids.to_a))
              SELECT categories.id
              FROM categories
              JOIN topic_tags ON topic_tags.topic_id = categories.topic_id
              WHERE topic_tags.tag_id IN (:tag_ids)
            SQL
          end
          ids.freeze
        end
    end

    # Denied tags and their synonyms. Tags outside a selective allowlist aren't
    # restricted themselves: they also label allowed topics.
    #
    # @returns [Set<Integer>]
    def restricted_tag_ids
      @denied_tag_ids
    end

    private

    def category_sql(table)
      return "TRUE" if @denied_category_ids.empty?

      "#{table}.category_id NOT IN (#{@denied_category_ids.to_a.join(",")})"
    end

    def in_sql(column, ids)
      return "FALSE" if ids.empty?

      "#{column} IN (#{ids.to_a.join(",")})"
    end

    def tagged_sql(table, tag_ids)
      return "FALSE" if tag_ids.empty?

      <<~SQL.squish
        EXISTS (
          SELECT 1 FROM topic_tags
          WHERE topic_tags.topic_id = #{table}.id AND topic_tags.tag_id IN (#{tag_ids.to_a.join(",")})
        )
      SQL
    end

    def subtree(ids)
      return Set.new.freeze if ids.empty?

      DB.query_single(SUBTREE_SQL, ids: ids.map(&:to_i)).to_set.freeze
    end

    def with_synonyms(ids)
      return Set.new.freeze if ids.empty?

      ids = ids.map(&:to_i)
      Tag.where(id: ids).or(Tag.where(target_tag_id: ids)).pluck(:id).to_set.freeze
    end
  end
end
