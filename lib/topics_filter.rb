# frozen_string_literal: true

class TopicsFilter
  attr_reader :topic_ids, :topic_notification_levels, :invalid_filters

  def initialize(guardian:, scope: nil, loaded_topic_users_reference: false)
    @loaded_topic_users_reference = loaded_topic_users_reference
    @guardian = guardian || Guardian.new
    @scope = scope || Topic.secured(@guardian)
    @topic_notification_levels = Set.new
    @invalid_filters = []
  end

  FILTER_ALIASES = {
    "categories" => "category",
    "tag-group" => "tag_group",
    "tags" => "tag",
    "groups" => "group",
    "user" => "users",
  }.freeze
  private_constant :FILTER_ALIASES

  QUOTED_VALUE_PATTERN = '"[^"]*"|\'[^\']*\''
  private_constant :QUOTED_VALUE_PATTERN

  FILTER_EXTRACTION_PATTERN =
    /(?<key_prefix>(?:-|=|-=|=-))?(?<key>[\w-]+):(?<value>#{QUOTED_VALUE_PATTERN}|[^\s]+)/
  private_constant :FILTER_EXTRACTION_PATTERN

  CATEGORY_SLUGS_PATTERN =
    /\A(?<category_slugs>([\p{L}\p{N}\-:]+)(?<delimiter>[,])?([\p{L}\p{N}\-:]+)?(\k<delimiter>[\p{L}\p{N}\-:]+)*)\z/
  private_constant :CATEGORY_SLUGS_PATTERN

  TAG_NAMES_PATTERN =
    /\A(?<tag_names>([\p{N}\p{L}\-_.]+)(?<delimiter>[,+])?([\p{N}\p{L}\-_.]+)?(\k<delimiter>[\p{N}\p{L}\-_.]+)*)\z/
  private_constant :TAG_NAMES_PATTERN

  TOKENIZER_PATTERN =
    /[\w-]+:(?:#{QUOTED_VALUE_PATTERN})|[\w-]+:[^\s]+|(?:#{QUOTED_VALUE_PATTERN})|[^\s]+/
  private_constant :TOKENIZER_PATTERN

  IN_VALUES =
    (
      TopicUser.notification_levels.keys.map(&:to_s) +
        %w[watching_first_post pinned bookmarked untagged new new-replies new-topics unseen]
    ).freeze
  private_constant :IN_VALUES

  SELF_NEGATING_FILTERS = %w[category order].freeze
  private_constant :SELF_NEGATING_FILTERS

  RANGE_FILTERS = {
    "activity-after" => %w[topics.bumped_at >=],
    "activity-before" => %w[topics.bumped_at <=],
    "created-after" => %w[topics.created_at >=],
    "created-before" => %w[topics.created_at <=],
    "latest-post-after" => %w[topics.last_posted_at >=],
    "latest-post-before" => %w[topics.last_posted_at <=],
    "likes-min" => %w[topics.like_count >=],
    "likes-max" => %w[topics.like_count <=],
    "likes-op-min" => %w[first_posts.like_count >=],
    "likes-op-max" => %w[first_posts.like_count <=],
    "posters-min" => %w[topics.participant_count >=],
    "posters-max" => %w[topics.participant_count <=],
    "posts-min" => %w[topics.posts_count >=],
    "posts-max" => %w[topics.posts_count <=],
    "views-min" => %w[topics.views >=],
    "views-max" => %w[topics.views <=],
  }.freeze
  private_constant :RANGE_FILTERS

  BOOKMARKED_FILTERS = { "bookmarked-before" => :lteq, "bookmarked-after" => :gteq }.freeze
  private_constant :BOOKMARKED_FILTERS

  def filter_from_query_string(query_string)
    return @scope if query_string.blank?

    filters = Hash.new { |hash, key| hash[key] = [] }

    query_string.scan(FILTER_EXTRACTION_PATTERN) do |key_prefix, key, value|
      filters[FILTER_ALIASES[key] || key] << [key_prefix, value]
    end

    filters.each do |filter, pairs|
      if SELF_NEGATING_FILTERS.include?(filter)
        positive, negated = pairs, []
      else
        negated, positive = pairs.partition { |key_prefix, _| key_prefix&.include?("-") }
      end

      positive = positive.reject { |_, value| unusable_value?(filter, value) }
      negated = negated.reject { |_, value| unusable_value?(filter, value) }

      apply_filter(**filter_arguments(filter, positive)) if positive.present?

      negated.each { |pair| apply_negated_filter(**filter_arguments(filter, [pair])) }
    end

    keywords = query_string.scan(TOKENIZER_PATTERN).reject { |word| word.include?(":") }.join(" ")

    if keywords.present? && keywords.length >= SiteSetting.min_search_term_length
      ts_query = Search.ts_query(term: keywords)
      @scope = @scope.where(<<~SQL)
          topics.id IN (
            SELECT topic_id
            FROM post_search_data
            JOIN posts ON posts.id = post_search_data.post_id
            WHERE search_data @@ #{ts_query} AND NOT posts.hidden AND posts.deleted_at IS NULL #{whisper_condition("posts")}
          )
        SQL
    end

    @scope
  end

  def self.add_filter_by_status(status, enabled: -> { true }, &block)
    custom_status_filters[status] = { block:, enabled: }
  end

  def self.custom_status_filters
    @custom_status_filters ||= {}
  end

  def filter_status(status:, category_id: nil)
    case status
    when "open"
      @scope = @scope.where("NOT topics.closed AND NOT topics.archived")
    when "closed"
      @scope = @scope.where("topics.closed")
    when "archived"
      @scope = @scope.where("topics.archived")
    when "listed"
      @scope = @scope.where("topics.visible")
    when "unlisted"
      @scope = @scope.where("NOT topics.visible")
    when "deleted"
      category = category_id.present? ? Category.find_by(id: category_id) : nil

      if @guardian.can_see_deleted_topics?(category)
        @scope = @scope.unscope(where: :deleted_at).where.not(topics: { deleted_at: nil })
      else
        @scope = @scope.none
      end
    when "public"
      @scope = @scope.joins(:category).where("NOT categories.read_restricted")
    when "noreplies"
      @scope = @scope.where("topics.posts_count = 1")
    when "single_user", "single-user"
      @scope = @scope.where("topics.participant_count = 1")
    when "scheduled"
      @scope =
        @scope.where(
          id:
            TopicTimer.where(status_type: TopicTimer.types[:publish_to_category]).select(
              :timerable_id,
            ),
        )
    else
      custom_filter = TopicsFilter.custom_status_filters[status]

      if custom_filter&.fetch(:enabled)&.call
        @scope = custom_filter[:block].call(@scope)
      else
        invalid_filter!("status:#{status}")
      end
    end

    @scope
  end

  def self.option(name, **attributes)
    key = name.delete_suffix(":").tr("-:", "__")
    { name:, description: I18n.t("filter.description.#{key}"), **attributes }
  end
  private_class_method :option

  def self.option_info(guardian)
    results = [
      option(
        "category:",
        alias: "categories:",
        priority: 1,
        type: "category",
        delimiters: [{ name: ",", description: I18n.t("filter.description.category_any") }],
        prefixes: [
          { name: "-", description: I18n.t("filter.description.exclude_category") },
          { name: "=", description: I18n.t("filter.description.category_without_subcategories") },
          {
            name: "-=",
            description: I18n.t("filter.description.exclude_category_without_subcategories"),
          },
        ],
      ),
      option(
        "topic:",
        type: "text",
        delimiters: [{ name: ",", description: I18n.t("filter.description.topic_any") }],
      ),
      option("activity-before:", type: "date"),
      option("activity-after:", type: "date"),
      option("created-before:", type: "date"),
      option("created-after:", type: "date", priority: 1),
      option(
        "created-by:",
        type: "username_group_list",
        delimiters: [{ name: ",", description: I18n.t("filter.description.created_by_multiple") }],
      ),
      option(
        "users:",
        type: "username",
        priority: 1,
        prefixes: [{ name: "-", description: I18n.t("filter.description.exclude_users") }],
        delimiters: [
          { name: ",", description: I18n.t("filter.description.users_any") },
          { name: "+", description: I18n.t("filter.description.users_all") },
        ],
      ),
      option("latest-post-before:", type: "date"),
      option("latest-post-after:", type: "date"),
      option("likes-min:", type: "number"),
      option("likes-max:", type: "number"),
      option("likes-op-min:", type: "number"),
      option("likes-op-max:", type: "number"),
      option("posts-min:", type: "number"),
      option("posts-max:", type: "number"),
      option("posters-min:", type: "number"),
      option("posters-max:", type: "number"),
      option("views-min:", type: "number"),
      option("views-max:", type: "number"),
      option("status:", priority: 1),
      option("status:open"),
      option("status:closed"),
      option("status:archived"),
      option("status:listed"),
      option("status:unlisted"),
      option("status:deleted"),
      option("status:public"),
      option("status:noreplies"),
      option("status:single-user"),
      option("status:scheduled"),
      option("order:", priority: 1),
      *ORDER_BY_MAPPINGS.keys.flat_map { |o| [option("order:#{o}"), option("order:#{o}-asc")] },
    ]

    if guardian.authenticated?
      results.concat(
        [
          option("in:", priority: 1),
          option("in:pinned"),
          option("in:bookmarked"),
          option("bookmarked-before:", type: "date"),
          option("bookmarked-after:", type: "date"),
          option("in:watching"),
          option("in:tracking"),
          option("in:muted"),
          option("in:normal"),
          option("in:watching-first-post"),
          option("in:new"),
          option("in:new-replies"),
          option("in:new-topics"),
          option("in:unseen"),
        ],
      )
    end

    if SiteSetting.tagging_enabled?
      results.push(
        option(
          "tag:",
          alias: "tags:",
          priority: 1,
          type: "tag",
          delimiters: [
            { name: ",", description: I18n.t("filter.description.tags_any") },
            { name: "+", description: I18n.t("filter.description.tags_all") },
          ],
          prefixes: [{ name: "-", description: I18n.t("filter.description.exclude_tag") }],
        ),
        option("in:untagged"),
        option(
          "tag-group:",
          alias: "tag_group:",
          type: "tag_group",
          prefixes: [{ name: "-", description: I18n.t("filter.description.exclude_tag_group") }],
        ),
      )
    end

    results.push(
      option(
        "group:",
        alias: "groups:",
        type: "group",
        priority: 1,
        prefixes: [{ name: "-", description: I18n.t("filter.description.exclude_group") }],
        delimiters: [
          { name: ",", description: I18n.t("filter.description.groups_any") },
          { name: "+", description: I18n.t("filter.description.groups_all") },
        ],
      ),
      option(
        "locale:",
        type: "text",
        delimiters: [{ name: ",", description: I18n.t("filter.description.locale_any") }],
        prefixes: [{ name: "-", description: I18n.t("filter.description.exclude_locale") }],
      ),
    )

    results = DiscoursePluginRegistry.apply_modifier(:topics_filter_options, results, guardian)

    results.each { |option| option[:prefixes] = [] if option[:name].start_with?("order:") }
  end

  private

  def apply_filter(filter:, filter_values:, key_prefixes:)
    case filter
    when *RANGE_FILTERS.keys
      filter_by_range(filter:, value: filter_values)
    when *BOOKMARKED_FILTERS.keys
      filter_by_bookmarked(filter:, value: filter_values)
    when "category"
      filter_categories(values: key_prefixes.zip(filter_values))
    when "created-by"
      filter_created_by(names: filter_values.flat_map { |value| value.split(",") })
    when "in"
      filter_in(values: filter_values)
    when "order"
      order_by(values: filter_values)
    when "users"
      filter_participation(values: key_prefixes.zip(filter_values), by: :users)
    when "group"
      filter_participation(values: key_prefixes.zip(filter_values), by: :groups)
    when "status"
      filter_values.each { |status| filter_status(status:) }
    when "tag_group"
      filter_tag_groups(values: key_prefixes.zip(filter_values))
    when "tag"
      filter_tags(values: key_prefixes.zip(filter_values))
    when "topic"
      filter_topics(values: filter_values)
    when "locale"
      filter_locale(values: key_prefixes.zip(filter_values))
    else
      if custom_filter = DiscoursePluginRegistry.custom_filter_mappings.find { it.key?(filter) }
        @scope = custom_filter[filter].call(@scope, filter_values, @guardian) || @scope
      end
    end
  end

  def apply_negated_filter(filter:, filter_values:, key_prefixes:)
    scope_before_filter = @scope
    loaded_topic_users_reference = @loaded_topic_users_reference
    topic_notification_levels = @topic_notification_levels.dup
    topic_ids = @topic_ids

    apply_filter(filter:, filter_values:, key_prefixes:)

    matched_topics = @scope.except(:order, :limit, :offset).reselect("topics.id")

    filter_acted = !@scope.equal?(scope_before_filter)

    @loaded_topic_users_reference = loaded_topic_users_reference
    @topic_notification_levels = topic_notification_levels
    @topic_ids = topic_ids

    @scope = filter_acted ? scope_before_filter.where.not(id: matched_topics) : scope_before_filter
  end

  def invalid_filter!(token)
    @invalid_filters << token
  end

  def unusable_value?(filter, value)
    return false if !RANGE_FILTERS.key?(filter) && !BOOKMARKED_FILTERS.key?(filter)
    return false if extract_and_validate_value_for(filter, [value]).present?

    invalid_filter!("#{filter}:#{value}")
    true
  end

  def filter_topics(values:)
    @topic_ids =
      values
        .flat_map { |value| value.split(",") }
        .filter_map { |value| Integer(value, 10, exception: false) }
        .select(&:positive?)
        .uniq

    @scope = @scope.in_order_of(:id, @topic_ids)
  end

  YYYY_MM_DD_REGEXP =
    /\A(?<year>[12][0-9]{3})-(?<month>0?[1-9]|1[0-2])-(?<day>0?[1-9]|[12]\d|3[01])\z/
  private_constant :YYYY_MM_DD_REGEXP

  def filter_arguments(filter, pairs)
    {
      filter:,
      filter_values: extract_and_validate_value_for(filter, pairs.map(&:last)),
      key_prefixes: pairs.map(&:first),
    }
  end

  def extract_and_validate_value_for(filter, values)
    case filter
    when "activity-before", "activity-after", "bookmarked-before", "bookmarked-after",
         "created-before", "created-after", "latest-post-before", "latest-post-after"
      value = values.last

      if match_data = value.match(YYYY_MM_DD_REGEXP)
        Time.zone.parse(
          "#{match_data[:year].to_i}-#{match_data[:month].to_i}-#{match_data[:day].to_i}",
        )
      elsif value =~ /\A\d+\z/
        # Handle integer as number of days ago (0 = today at midnight)
        days = value.to_i
        return nil if days < 0
        days.days.ago.beginning_of_day
      end
    when "likes-min", "likes-max", "likes-op-min", "likes-op-max", "posts-min", "posts-max",
         "posters-min", "posters-max", "views-min", "views-max"
      value = values.last
      value if value =~ /\A\d+\z/
    when "order"
      values.flat_map { |value| value.split(",") }
    when "created-by"
      values.flat_map { |value| value.split(",").map { |username| username.delete_prefix("@") } }
    else
      values
    end
  end

  def filter_by_range(filter:, value:)
    return if value.nil?

    column, operator = RANGE_FILTERS[filter]
    @scope = joins_first_posts(@scope) if column.start_with?("first_posts.")
    @scope = @scope.where("#{column} #{operator} ?", value)
  end

  def filter_by_bookmarked(filter:, value:)
    return @scope = @scope.none if !@guardian.authenticated?
    return if value.nil?

    user_id = @guardian.user.id.to_i
    date_comparison = BOOKMARKED_FILTERS[filter]
    bookmarks_table = Bookmark.arel_table

    topic_bookmarks =
      Bookmark
        .where(user_id: user_id, bookmarkable_type: "Topic")
        .where(bookmarks_table[:created_at].public_send(date_comparison, value))
        .select(:bookmarkable_id)

    post_bookmarks =
      Bookmark
        .joins(
          "INNER JOIN posts ON posts.id = bookmarks.bookmarkable_id AND posts.deleted_at IS NULL",
        )
        .where(user_id: user_id, bookmarkable_type: "Post")
        .where(bookmarks_table[:created_at].public_send(date_comparison, value))
        .select("posts.topic_id")

    @scope = @scope.where(id: topic_bookmarks).or(@scope.where(id: post_bookmarks))
  end

  # users:a,b => any of a or b participated in the topic
  # users:a+b => both a and b participated in the topic
  # group: matches the same way, on group membership instead of the user.
  def filter_participation(values:, by:)
    values.each do |key_prefix, value|
      require_all = value.include?("+")
      names = value.split(require_all ? "+" : ",").map(&:downcase).reject(&:blank?)
      names = [] if require_all && value.include?(",")

      if names.empty?
        invalid_filter!("#{by == :users ? "users" : "group"}:#{value}")
        @scope = @scope.none if !key_prefix&.include?("-")
        next
      end

      ids = participant_ids(by, names)

      if ids.empty? || (require_all && ids.length < names.length)
        @scope = @scope.none
        next
      end

      if require_all
        ids.each { |id| @scope = @scope.where(participation_sql(by, [id])) }
      else
        @scope = @scope.where(participation_sql(by, ids))
      end
    end
  end

  def participant_ids(by, names)
    return User.not_staged.where(username_lower: names).pluck(:id) if by == :users

    Group
      .visible_groups(@guardian.user)
      .members_visible_groups(@guardian.user)
      .where("lower(name) IN (?)", names)
      .pluck(:id)
  end

  def participation_sql(by, ids)
    if by == :groups
      join = "JOIN group_users gu ON gu.user_id = p.user_id"
      column = "gu.group_id"
    else
      join = nil
      column = "p.user_id"
    end

    <<~SQL
      EXISTS (
        SELECT 1
        FROM posts p
        #{join}
        WHERE p.topic_id = topics.id
          AND #{column} IN (#{ids.join(",")})
          AND p.deleted_at IS NULL
          #{whisper_condition("p")}
      )
    SQL
  end

  def filter_categories(values:)
    include_category_ids = []
    exclude_category_ids = []
    include_requested = false

    values.each do |key_prefix, value|
      exclude_categories = key_prefix&.include?("-")
      exclude_subcategories = key_prefix&.include?("=")

      match = value.match(CATEGORY_SLUGS_PATTERN)

      if match.nil?
        invalid_filter!("category:#{value}")
        @scope = @scope.none if !exclude_categories
        next
      end

      slugs = match[:category_slugs].split(match[:delimiter] || ",")
      ids = category_ids_from_slugs(slugs, exclude_subcategories:)

      if exclude_categories
        exclude_category_ids.concat(ids)
      else
        include_requested = true
        include_category_ids.concat(ids)
      end
    end

    if include_category_ids.present?
      @scope = @scope.where("topics.category_id IN (?)", include_category_ids)
    elsif include_requested
      @scope = @scope.none
      return
    end

    # Use `NOT EXISTS` instead of `NOT IN` to avoid performance issues with large arrays.
    @scope = @scope.where(<<~SQL) if exclude_category_ids.present?
      NOT EXISTS (
        SELECT 1
        FROM unnest(array[#{exclude_category_ids.join(",")}]) AS excluded_categories(category_id)
        WHERE topics.category_id IS NULL OR excluded_categories.category_id = topics.category_id
      )
      SQL
  end

  def filter_created_by(names:)
    names = names.map(&:downcase)

    if @guardian.authenticated?
      names = names.map { |name| name == "me" ? @guardian.user.username_lower : name }
    end

    user_ids = User.where(username_lower: names).pluck(:id)
    return @scope = @scope.where(user_id: user_ids) if user_ids.any?

    group_ids =
      Group
        .visible_groups(@guardian.user)
        .members_visible_groups(@guardian.user)
        .where("lower(name) IN (?)", names)
        .pluck(:id)

    if group_ids.any?
      return @scope = @scope.where(user_id: GroupUser.where(group_id: group_ids).select(:user_id))
    end

    @scope = @scope.none
  end

  def apply_custom_in_filters!(values)
    values.dup.each do |value|
      custom_key = "in:#{value}"
      custom_match =
        DiscoursePluginRegistry.custom_filter_mappings.find { |hash| hash.key?(custom_key) }
      next if custom_match.nil?

      @scope = custom_match[custom_key].call(@scope, custom_key, @guardian) || @scope
      values.delete(value)
    end
  end

  def ensure_topic_users_reference!
    return if !@guardian.authenticated? || @loaded_topic_users_reference

    @scope =
      @scope.joins(
        "LEFT JOIN topic_users tu ON tu.topic_id = topics.id
        AND tu.user_id = #{@guardian.user.id.to_i}",
      )
    @loaded_topic_users_reference = true
  end

  def topic_user_scope(levels)
    @scope.where("tu.notification_level IN (?)", levels)
  end

  def watching_first_post_scope
    TopicQuery.watching_first_post_filter(@scope, @guardian.user)
  end

  def combine_scopes_with_or(scope1, scope2)
    @scope.joins_values.concat(scope1.joins_values, scope2.joins_values).uniq!
    @scope.merge(scope1.or(scope2))
  end

  def filter_in(values:)
    values.uniq!

    values.map! { |value| value.split(",") }.flatten!

    values.map! { |value| value == "watching-first-post" ? "watching_first_post" : value }

    if values.delete("pinned")
      @scope =
        @scope.where(
          "topics.pinned_at IS NOT NULL AND (topics.pinned_until IS NULL OR ? < topics.pinned_until)",
          Time.zone.now,
        )
    end

    if values.delete("untagged")
      @scope =
        @scope.where("NOT EXISTS (SELECT 1 FROM topic_tags WHERE topic_tags.topic_id = topics.id)")
    end

    apply_custom_in_filters!(values)

    if @guardian.authenticated?
      if values.delete("new-topics")
        ensure_topic_users_reference!
        @scope =
          TopicQuery.new_filter(
            @scope,
            treat_as_new_topic_start_date: @guardian.user.user_option.treat_as_new_topic_start_date,
          )
      end

      if values.delete("new-replies")
        ensure_topic_users_reference!
        @scope = TopicQuery.unread_filter(@scope, whisperer: @guardian.user.whisperer?)
      end

      if values.delete("new")
        ensure_topic_users_reference!
        new_topics =
          TopicQuery.new_filter(
            @scope,
            treat_as_new_topic_start_date: @guardian.user.user_option.treat_as_new_topic_start_date,
          )
        unread_topics = TopicQuery.unread_filter(@scope, whisperer: @guardian.user.whisperer?)
        @scope = combine_scopes_with_or(new_topics, unread_topics)
      end

      if values.delete("unseen")
        ensure_topic_users_reference!
        @scope = TopicQuery.unseen_filter(@scope, @guardian.user)
      end

      if values.delete("bookmarked")
        ensure_topic_users_reference!
        @scope = @scope.where("tu.bookmarked")
      end

      levels = values.filter_map { |value| TopicUser.notification_levels[value.to_sym] }
      @topic_notification_levels.merge(levels)

      watching_first_post = values.include?("watching_first_post")

      if watching_first_post && levels.present?
        ensure_topic_users_reference!
        @scope = combine_scopes_with_or(topic_user_scope(levels), watching_first_post_scope)
      elsif watching_first_post
        @scope = @scope.merge(watching_first_post_scope)
      elsif levels.present?
        ensure_topic_users_reference!
        @scope = @scope.merge(topic_user_scope(levels))
      end
    elsif values.present?
      @scope = @scope.none
    end

    (values - IN_VALUES).each { |value| invalid_filter!("in:#{value}") }
  end

  def category_ids_from_slugs(slugs, exclude_subcategories: false)
    return [] if slugs.empty?

    category_ids = Category.ids_from_slugs(slugs)

    category_ids =
      Category
        .where(id: category_ids)
        .filter { |category| @guardian.can_see_category?(category) }
        .map(&:id)

    if !exclude_subcategories
      category_ids = category_ids.flat_map { |category_id| Category.subcategory_ids(category_id) }
    end

    category_ids
  end

  def filter_tag_groups(values:)
    values.each do |_, value|
      tag_group_ids = TagGroup.visible(@guardian).where_name(strip_quotes(value)).pluck(:id)

      tag_ids = TagGroupMembership.where(tag_group_id: tag_group_ids).select(:tag_id)

      @scope = @scope.where(id: TopicTag.where(tag_id: tag_ids).select(:topic_id))
    end
  end

  def strip_quotes(value)
    value.gsub(/\A["']|["']\z/, "")
  end

  def filter_tags(values:)
    return if !SiteSetting.tagging_enabled?

    values.each do |key_prefix, value|
      if key_prefix && key_prefix != "-"
        invalid_filter!("#{key_prefix}tag:#{value}")
        next
      end

      match = value.match(TAG_NAMES_PATTERN)

      if match.nil?
        invalid_filter!("tag:#{value}")
        @scope = @scope.none if key_prefix != "-"
        next
      end

      tags = match[:tag_names].split(match[:delimiter])
      tag_ids = DiscourseTagging.visible_tag_ids_resolving_synonyms(tags, @guardian)

      if match[:delimiter] == ","
        include_topics_with_any_tags(tag_ids)
      elsif tag_ids.length < tags.length
        @scope = @scope.none
      else
        include_topics_with_all_tags(tag_ids)
      end
    end
  end

  def topic_tags_alias
    @topic_tags_alias ||= 0
    "tt#{@topic_tags_alias += 1}"
  end

  def include_topics_with_all_tags(tag_ids)
    tag_ids.each do |tag_id|
      sql_alias = topic_tags_alias
      @scope =
        @scope.joins(
          "INNER JOIN topic_tags #{sql_alias} ON #{sql_alias}.topic_id = topics.id AND #{sql_alias}.tag_id = #{tag_id}",
        )
    end
  end

  def include_topics_with_any_tags(tag_ids)
    @scope = @scope.where(id: TopicTag.where(tag_id: tag_ids).select(:topic_id))
  end

  def filter_locale(values:)
    locales = values.flat_map { |_, value| value.split(",").map(&:strip) }.reject(&:blank?)
    @scope = @scope.where(locale: locales) if locales.present?
  end

  ORDER_BY_MAPPINGS = {
    "activity" => {
      column: "topics.bumped_at",
    },
    "category" => {
      column: "categories.name",
      scope: -> { @scope.joins(:category) },
    },
    "created" => {
      column: "topics.created_at",
    },
    "latest-post" => {
      column: "topics.last_posted_at",
    },
    "likes" => {
      column: "topics.like_count",
    },
    "likes-op" => {
      column: "first_posts.like_count",
      scope: -> { joins_first_posts(@scope) },
    },
    "posters" => {
      column: "topics.participant_count",
    },
    "posts" => {
      column: "topics.posts_count",
    },
    "title" => {
      column: "LOWER(topics.title)",
    },
    "views" => {
      column: "topics.views",
    },
    "hot" => {
      column: "COALESCE(topic_hot_scores.score, 0)",
      scope: -> do
        @scope.joins("LEFT JOIN topic_hot_scores ON topic_hot_scores.topic_id = topics.id")
      end,
    },
    "read" => {
      column: "tu.last_visited_at",
      scope: -> do
        if @guardian.authenticated?
          ensure_topic_users_reference!
          @scope.where.not(tu: { last_visited_at: nil })
        else
          # make sure this works for anon (particularly selection)
          @scope.joins("LEFT JOIN topic_users tu ON 1 = 0")
        end
      end,
    },
  }
  private_constant :ORDER_BY_MAPPINGS

  ORDER_BY_REGEXP = /\A(?<order_by>#{ORDER_BY_MAPPINGS.keys.join("|")})(?<asc>-asc)?\z/
  private_constant :ORDER_BY_REGEXP

  def order_by(values:)
    values.each do |value|
      match_data = value.match(ORDER_BY_REGEXP)
      if match_data
        mapping = ORDER_BY_MAPPINGS[match_data[:order_by]]
        @scope = instance_exec(&mapping[:scope]) if mapping[:scope]
        @scope = @scope.order("#{mapping[:column]} #{match_data[:asc] ? "ASC" : "DESC"}")
      else
        match_data = value.match(/^(?<column>.*?)(?:-(?<asc>asc))?$/)
        key = "order:#{match_data[:column]}"
        if custom_match =
             DiscoursePluginRegistry.custom_filter_mappings.find { |hash| hash.key?(key) }
          dir = match_data[:asc] ? "ASC" : "DESC"
          @scope = custom_match[key].call(@scope, dir, @guardian) || @scope
        else
          invalid_filter!("order:#{value}")
        end
      end
    end
  end

  def joins_first_posts(scope)
    scope.joins(
      "INNER JOIN posts AS first_posts ON first_posts.topic_id = topics.id AND first_posts.post_number = 1",
    )
  end

  def whisper_condition(table_alias)
    if @guardian.can_see_whispers?
      ""
    else
      "AND #{table_alias}.post_type != #{Post.types[:whisper]}"
    end
  end
end
