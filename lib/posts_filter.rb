# frozen_string_literal: true

class PostsFilter
  FILTER_ALIASES = {
    "category" => "category",
    "categories" => "category",
    "exclude_category" => "category",
    "exclude_categories" => "category",
    "tag" => "tag",
    "tags" => "tag",
    "exclude_tag" => "tag",
    "exclude_tags" => "tag",
    "username" => "usernames",
    "usernames" => "usernames",
    "group" => "groups",
    "groups" => "groups",
    "topic" => "topics",
    "topics" => "topics",
    "created_after" => "after",
    "created_before" => "before",
    "topic_created_after" => "topic_after",
    "topic_created_before" => "topic_before",
  }
  private_constant :FILTER_ALIASES

  FILTER_PREFIX_PATTERN = /\A(?<prefix>-=|=-|-|=)?(?<key>[\w-]+):(?<value>.+)\z/
  private_constant :FILTER_PREFIX_PATTERN

  TOKENIZER_PATTERN = /(?:[^\s"']+|"[^"]*"|'[^']*')+/
  private_constant :TOKENIZER_PATTERN

  ORDER_VALUES = %w[latest oldest latest_topic oldest_topic likes].freeze
  POST_TYPE_VALUES = %w[regular all first reply moderator_action small_action whisper].freeze
  STORED_POST_TYPE_VALUES = %w[regular moderator_action small_action whisper].freeze
  POST_TYPE_SCOPE_VALUES = (STORED_POST_TYPE_VALUES + %w[all]).freeze
  STATUS_VALUES = %w[
    open
    closed
    archived
    listed
    unlisted
    deleted
    public
    noreplies
    single_user
  ].freeze
  CUSTOM_FILTER_PREFIXES = [nil, ""].freeze
  private_constant :CUSTOM_FILTER_PREFIXES

  attr_reader :term, :filters, :order, :guardian, :limit, :offset, :invalid_filters

  def self.add_filter(name, aliases: [], enabled: -> { true }, &block)
    raise ArgumentError, "block is required" if block.blank?

    custom_filters[name.to_s] = { block: block, enabled: enabled, aliases: aliases.map(&:to_s) }
  end

  def self.remove_filter(name)
    custom_filters.delete(name.to_s)
  end

  def self.custom_filters
    PostsFilter.instance_variable_get(:@custom_filters) ||
      PostsFilter.instance_variable_set(:@custom_filters, {})
  end

  def self.custom_filter_for(key)
    custom_filters.find { |name, config| name == key || config[:aliases].include?(key) }&.last
  end

  def self.word_to_date(str)
    ::Search.word_to_date(str)
  end

  def self.category_ids_from_param(category_param, exact: false)
    category_param
      .to_s
      .split(",")
      .map(&:strip)
      .reject(&:blank?)
      .flat_map { |category_value| category_ids_from_value(category_value, exact: exact) }
      .uniq
  end

  def self.category_ids_from_value(category_value, exact: false)
    category_value = category_value.to_s.strip
    exact = true if category_value.start_with?("=")
    category_value = category_value[1..] if category_value.start_with?("=")
    category_value = strip_surrounding_quotes(category_value.strip)

    category = find_category(category_value)
    return [] if category.blank?

    category_ids = [category.id]
    category_ids.concat(Category.subcategory_ids(category.id)) if !exact
    category_ids
  end

  def self.find_category(category_value)
    parent_value, child_value = category_value.split(%r{[/:]}, 2)

    if child_value.present?
      parent_category_ids = matching_categories(parent_value).select(:id)

      matching_categories(child_value)
        .where(parent_category_id: parent_category_ids)
        .order("case when parent_category_id is null then 0 else 1 end")
        .first
    else
      matching_categories(category_value).order(
        "case when parent_category_id is null then 0 else 1 end",
      ).first
    end
  end

  def self.matching_categories(category_value)
    categories =
      Category.where(
        "#{Category.normalize_sql("slug")} = #{Category.normalize_sql("?")} OR " \
          "#{Category.normalize_sql("name")} = #{Category.normalize_sql("?")}",
        category_value,
        category_value,
      )

    if category_value.match?(/\A\d{1,10}\z/)
      categories = categories.or(Category.where(id: category_value.to_i))
    end

    categories
  end

  def self.strip_surrounding_quotes(value)
    if value.length >= 2 &&
         (
           (value.start_with?("\"") && value.end_with?("\"")) ||
             (value.start_with?("'") && value.end_with?("'"))
         )
      value[1...-1]
    else
      value
    end
  end

  def self.option_value_info(filter_name, values)
    values.map do |value|
      {
        name: "#{filter_name}:#{value}",
        description:
          I18n.t(
            "posts_filter.description.#{filter_name}_#{value}",
            default: value.to_s.tr("_", " ").capitalize,
          ),
      }
    end
  end

  def self.option_info(guardian)
    results = [
      {
        name: "category:",
        alias: "categories:",
        description: I18n.t("posts_filter.description.category"),
        priority: 1,
        type: "category",
        delimiters: [{ name: ",", description: I18n.t("posts_filter.description.category_any") }],
        prefixes: [
          { name: "-", description: I18n.t("posts_filter.description.exclude_category") },
          {
            name: "=",
            description: I18n.t("posts_filter.description.category_without_subcategories"),
          },
          {
            name: "-=",
            description: I18n.t("posts_filter.description.exclude_category_without_subcategories"),
          },
        ],
      },
      {
        name: "tag:",
        alias: "tags:",
        description: I18n.t("posts_filter.description.tag"),
        priority: 1,
        type: "tag",
        delimiters: [{ name: ",", description: I18n.t("posts_filter.description.tags_any") }],
        prefixes: [{ name: "-", description: I18n.t("posts_filter.description.exclude_tag") }],
      },
      {
        name: "username:",
        alias: "usernames:",
        description: I18n.t("posts_filter.description.username"),
        type: "username",
        delimiters: [{ name: ",", description: I18n.t("posts_filter.description.usernames_any") }],
      },
      {
        name: "group:",
        alias: "groups:",
        description: I18n.t("posts_filter.description.group"),
        type: "group",
        delimiters: [{ name: ",", description: I18n.t("posts_filter.description.groups_any") }],
      },
      {
        name: "topic:",
        alias: "topics:",
        description: I18n.t("posts_filter.description.topic"),
        type: "number",
        prefixes: [{ name: "-", description: I18n.t("posts_filter.description.exclude_topic") }],
      },
      { name: "after:", description: I18n.t("posts_filter.description.after"), type: "date" },
      { name: "before:", description: I18n.t("posts_filter.description.before"), type: "date" },
      {
        name: "topic_after:",
        description: I18n.t("posts_filter.description.topic_after"),
        type: "date",
      },
      {
        name: "topic_before:",
        description: I18n.t("posts_filter.description.topic_before"),
        type: "date",
      },
      {
        name: "keywords:",
        description: I18n.t("posts_filter.description.keywords"),
        type: "string",
      },
      {
        name: "topic_keywords:",
        description: I18n.t("posts_filter.description.topic_keywords"),
        type: "string",
      },
      {
        name: "post_type:",
        description: I18n.t("posts_filter.description.post_type"),
        priority: 1,
      },
      *option_value_info("post_type", POST_TYPE_VALUES),
      { name: "status:", description: I18n.t("posts_filter.description.status"), priority: 1 },
      *option_value_info("status", STATUS_VALUES),
      { name: "order:", description: I18n.t("posts_filter.description.order"), priority: 1 },
      *option_value_info("order", ORDER_VALUES),
      {
        name: "max_results:",
        description: I18n.t("posts_filter.description.max_results"),
        type: "number",
      },
    ]

    DiscoursePluginRegistry.apply_modifier(:posts_filter_options, results, guardian)
  end

  def initialize(query_string = nil, guardian: nil, limit: nil, offset: nil, scope: Post.all)
    @guardian = guardian || Guardian.new
    @base_scope = scope
    @initial_limit = limit
    @initial_offset = offset
    @limit = limit
    @offset = offset
    @term = query_string.to_s.strip
    reset_filter_state!
    process_filters(@term)
  end

  def filter_from_query_string(query_string)
    @term = query_string.to_s.strip
    reset_filter_state!
    process_filters(@term)
    search
  end

  def set_order!(order)
    @order = order
  end

  def limit_by_user!(limit)
    @limit = limit if limit.to_i < @limit.to_i || @limit.nil?
  end

  def search
    base_relation = secure_base_relation
    filtered = filtered_relation(base_relation)
    ordered = order_relation(filtered)
    ordered = ordered.limit(@limit) if @limit.to_i > 0
    ordered = ordered.offset(@offset) if @offset.to_i > 0
    ordered
  end

  private

  def reset_filter_state!
    @filters = []
    @limit = @initial_limit
    @offset = @initial_offset
    @order = :latest_post
    @invalid_filters = []
    @or_groups = []
  end

  def secure_base_relation
    include_deleted_topics = include_deleted_topics?

    base_scope = @base_scope
    base_scope = base_scope.with_deleted if include_deleted_topics

    topic_scope = Topic.secured(@guardian)
    topic_scope = topic_scope.with_deleted if include_deleted_topics

    # Use a raw topic join because the association join applies Topic's deleted_at
    # default scope in the ON clause, which would hide status:deleted matches.
    relation =
      base_scope
        .secured(@guardian)
        .joins("INNER JOIN topics ON topics.id = posts.topic_id")
        .merge(topic_scope)
        .where("topics.archetype = ?", Archetype.default)

    relation = @guardian.filter_hidden_posts(relation)
    relation = relation.where(topics: { visible: true }) if guardian_should_hide_unlisted_topics?

    if SiteSetting.shared_drafts_category.present? && !@guardian.can_see_shared_draft?
      relation =
        relation.where.not(topics: { category_id: SiteSetting.shared_drafts_category.to_i })
    end

    relation
  end

  def guardian_should_hide_unlisted_topics?
    @guardian.anonymous? || !@guardian.can_see_unlisted_topics?
  end

  def include_deleted_topics?
    return false if !@guardian.can_see_deleted_topics?(nil)

    parsed_filters = @filters + @or_groups.flatten
    parsed_filters.any? { |filter| deleted_status_filter?(filter) }
  end

  def deleted_status_filter?(filter)
    filter[:key] == "status" && filter[:value].casecmp?("deleted")
  end

  def filtered_relation(base_relation)
    if @or_groups.any?
      or_relations =
        @or_groups.map do |or_group|
          or_group.reduce(
            relation_for_filter_group(base_relation, or_group),
          ) { |relation, parsed_filter| apply_filter(relation, parsed_filter) }
        end

      union_sql =
        or_relations.map { |relation| relation.reselect("posts.id").to_sql }.join(" UNION ")
      base_relation.where("posts.id IN (#{union_sql})")
    else
      @filters.reduce(
        relation_for_filter_group(base_relation, @filters),
      ) { |relation, parsed_filter| apply_filter(relation, parsed_filter) }
    end
  end

  def relation_for_filter_group(base_relation, filters)
    relation = base_relation

    if include_deleted_topics? && filters.none? { |filter| deleted_status_filter?(filter) }
      relation = relation.where(posts: { deleted_at: nil }, topics: { deleted_at: nil })
    end

    if filters.none? { |filter| post_type_scope_filter?(filter) }
      relation = relation.where(posts: { post_type: Post.types[:regular] })
    end

    relation
  end

  def post_type_scope_filter?(filter)
    filter[:key] == "post_type" && POST_TYPE_SCOPE_VALUES.include?(filter[:value].downcase)
  end

  def order_relation(relation)
    case @order
    when :latest_post
      relation.order("posts.created_at DESC")
    when :oldest_post
      relation.order("posts.created_at ASC")
    when :latest_topic
      relation.order("topics.created_at DESC, posts.post_number DESC")
    when :oldest_topic
      relation.order("topics.created_at ASC, posts.post_number ASC")
    when :likes
      relation.order("posts.like_count DESC, posts.created_at DESC")
    else
      relation
    end
  end

  def process_filters(term)
    return if term.blank?

    or_parts = term.split(/\s+OR\s+/i)

    if or_parts.size > 1
      or_parts.each do |or_part|
        group_filters = []
        process_filter_group(or_part.strip, group_filters)
        @or_groups << group_filters if group_filters.any?
      end
    else
      process_filter_group(term, @filters)
    end
  end

  def process_filter_group(term_part, filter_collection)
    term_part
      .to_s
      .scan(TOKENIZER_PATTERN)
      .each do |word|
        next if word.blank?

        parsed_filter = parse_filter(word)
        if parsed_filter && valid_filter?(parsed_filter)
          filter_collection << parsed_filter
        else
          invalid_filters << word
        end
      end
  end

  def parse_filter(word)
    match = word.match(FILTER_PREFIX_PATTERN)
    return if match.blank?

    raw_key = match[:key].downcase
    key = FILTER_ALIASES[raw_key] || raw_key
    prefix = match[:prefix].to_s

    {
      token: word,
      raw_key: raw_key,
      key: key,
      prefix: prefix,
      value: self.class.strip_surrounding_quotes(match[:value].to_s.strip),
      exclude: prefix.include?("-") || raw_key.start_with?("exclude_"),
      exact: prefix.include?("="),
    }
  end

  def valid_filter?(parsed_filter)
    key = parsed_filter[:key]
    value = parsed_filter[:value]

    case key
    when "category", "tag"
      true
    when "before", "after", "topic_before", "topic_after", "keywords", "topic_keywords",
         "usernames", "groups"
      !parsed_filter[:exclude] && parsed_filter[:prefix].exclude?("=")
    when "topics"
      parsed_filter[:prefix].exclude?("=")
    when "status"
      !parsed_filter[:exclude] && STATUS_VALUES.include?(value.downcase)
    when "post_type"
      !parsed_filter[:exclude] && POST_TYPE_VALUES.include?(value.downcase)
    when "max_results"
      !parsed_filter[:exclude] && value.match?(/\A\d+\z/)
    when "order"
      !parsed_filter[:exclude] && ORDER_VALUES.include?(value.downcase)
    else
      custom_filter = self.class.custom_filter_for(key)
      custom_filter.present? && CUSTOM_FILTER_PREFIXES.include?(parsed_filter[:prefix]) &&
        custom_filter[:enabled].call
    end
  end

  def apply_filter(relation, parsed_filter)
    case parsed_filter[:key]
    when "status"
      filter_status(relation, parsed_filter[:value].downcase)
    when "before"
      filter_by_date(relation, "posts.created_at < ?", parsed_filter[:value])
    when "after"
      filter_by_date(relation, "posts.created_at > ?", parsed_filter[:value])
    when "topic_before"
      filter_by_date(relation, "topics.created_at < ?", parsed_filter[:value])
    when "topic_after"
      filter_by_date(relation, "topics.created_at > ?", parsed_filter[:value])
    when "tag"
      filter_tags(relation, parsed_filter)
    when "keywords"
      filter_keywords(relation, parsed_filter[:value])
    when "topic_keywords"
      filter_topic_keywords(relation, parsed_filter[:value])
    when "category"
      filter_categories(relation, parsed_filter)
    when "usernames"
      filter_usernames(relation, parsed_filter[:value])
    when "groups"
      filter_groups(relation, parsed_filter[:value])
    when "max_results"
      limit_by_user!(parsed_filter[:value].to_i)
      relation
    when "order"
      set_order!(order_value(parsed_filter[:value]))
      relation
    when "topics"
      filter_topics(relation, parsed_filter)
    when "post_type"
      filter_post_type(relation, parsed_filter[:value])
    else
      apply_custom_filter(relation, parsed_filter)
    end
  end

  def filter_status(relation, status)
    case status
    when "open"
      relation.where("topics.closed = false AND topics.archived = false")
    when "closed"
      relation.where("topics.closed = true")
    when "archived"
      relation.where("topics.archived = true")
    when "listed"
      relation.where("topics.visible = true")
    when "unlisted"
      relation.where("topics.visible = false")
    when "deleted"
      return relation.where("1 = 0") if !@guardian.can_see_deleted_topics?(nil)

      relation.where.not(topics: { deleted_at: nil })
    when "public"
      relation.joins("LEFT JOIN categories ON categories.id = topics.category_id").where(
        "topics.category_id IS NULL OR NOT categories.read_restricted",
      )
    when "noreplies"
      relation.where("topics.posts_count = 1")
    when "single_user"
      relation.where("topics.participant_count = 1")
    else
      relation
    end
  end

  def filter_by_date(relation, condition, date_str)
    if date = self.class.word_to_date(date_str)
      relation.where(condition, date)
    else
      relation
    end
  end

  def filter_tags(relation, parsed_filter)
    tag_names = split_values(parsed_filter[:value])
    return relation if tag_names.empty?

    tag_ids = DiscourseTagging.filter_visible(Tag, @guardian).where_name(tag_names).pluck(:id)
    return relation.where("1 = 0") if tag_ids.empty? && !parsed_filter[:exclude]
    return relation if tag_ids.empty?

    topic_ids = TopicTag.where(tag_id: tag_ids).select(:topic_id)
    if parsed_filter[:exclude]
      relation.where.not(topic_id: topic_ids)
    else
      relation.where(topic_id: topic_ids)
    end
  end

  def filter_keywords(relation, keywords_param)
    keywords = split_values(keywords_param)
    return relation if keywords.empty?

    ts_query = keywords.map { |keyword| keyword.gsub(/['\\]/, " ") }.join(" | ")
    relation.joins("JOIN post_search_data ON post_search_data.post_id = posts.id").where(
      "post_search_data.search_data @@ to_tsquery(?, ?)",
      ::Search.ts_config,
      ts_query,
    )
  end

  def filter_topic_keywords(relation, keywords_param)
    keywords = split_values(keywords_param)
    return relation if keywords.empty?

    ts_query = keywords.map { |keyword| keyword.gsub(/['\\]/, " ") }.join(" | ")
    hidden_posts_condition = @guardian.can_see_all_hidden_posts? ? "" : "AND posts2.hidden = false"
    whisper_condition =
      @guardian.can_see_whispers? ? "" : "AND posts2.post_type <> #{Post.types[:whisper]}"

    relation.where(
      "posts.topic_id IN (
        SELECT posts2.topic_id
        FROM posts posts2
        JOIN post_search_data ON post_search_data.post_id = posts2.id
        WHERE post_search_data.search_data @@ to_tsquery(?, ?)
        AND posts2.deleted_at IS NULL
        AND posts2.post_type IN (?)
        #{hidden_posts_condition}
        #{whisper_condition}
      )",
      ::Search.ts_config,
      ts_query,
      Topic.visible_post_types(@guardian.user),
    )
  end

  def filter_categories(relation, parsed_filter)
    category_ids =
      self.class.category_ids_from_param(parsed_filter[:value], exact: parsed_filter[:exact])

    return relation.where("1 = 0") if category_ids.empty? && !parsed_filter[:exclude]
    return relation if category_ids.empty?

    topic_ids = Topic.where(category_id: category_ids).select(:id)
    if parsed_filter[:exclude]
      relation.where.not(topic_id: topic_ids)
    else
      relation.where(topic_id: topic_ids)
    end
  end

  def filter_usernames(relation, usernames_param)
    usernames = split_values(usernames_param).map(&:downcase)
    user_ids = User.where(username_lower: usernames).pluck(:id)

    if user_ids.empty?
      relation.where("1 = 0")
    else
      relation.where("posts.user_id IN (?)", user_ids)
    end
  end

  def filter_groups(relation, groups_param)
    group_names = split_values(groups_param).map(&:downcase)
    found_group_ids =
      Group
        .visible_groups(@guardian.user)
        .members_visible_groups(@guardian.user)
        .where("LOWER(name) IN (?)", group_names)
        .pluck(:id)

    return relation.where("1 = 0") if found_group_ids.empty?

    relation.where(
      "posts.user_id IN (
        SELECT group_users.user_id FROM group_users
        WHERE group_users.group_id IN (?)
      )",
      found_group_ids,
    )
  end

  def filter_topics(relation, parsed_filter)
    topic_ids = split_values(parsed_filter[:value]).map(&:to_i).reject(&:zero?)
    return parsed_filter[:exclude] ? relation : relation.where("1 = 0") if topic_ids.empty?

    if parsed_filter[:exclude]
      relation.where.not(topic_id: topic_ids)
    else
      relation.where("posts.topic_id IN (?)", topic_ids)
    end
  end

  def filter_post_type(relation, post_type)
    post_type_value = post_type.downcase

    case post_type_value
    when "first"
      relation.where("posts.post_number = 1")
    when "reply"
      relation.where("posts.post_number > 1")
    when "all"
      relation
    else
      relation.where(posts: { post_type: Post.types[post_type_value.to_sym] })
    end
  end

  def apply_custom_filter(relation, parsed_filter)
    custom_filter = self.class.custom_filter_for(parsed_filter[:key])
    return relation if custom_filter.blank?

    custom_filter[:block].call(relation, [parsed_filter[:value]], @guardian) || relation
  end

  def order_value(value)
    case value.downcase
    when "latest"
      :latest_post
    when "oldest"
      :oldest_post
    when "latest_topic"
      :latest_topic
    when "oldest_topic"
      :oldest_topic
    when "likes"
      :likes
    end
  end

  def split_values(value)
    value
      .to_s
      .split(",")
      .map { |part| self.class.strip_surrounding_quotes(part.strip) }
      .reject(&:blank?)
  end
end
