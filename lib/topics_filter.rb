# frozen_string_literal: true

class TopicsFilter
  attr_reader :topic_notification_levels

  def initialize(guardian:, scope: Topic.all, loaded_topic_users_reference: false)
    @loaded_topic_users_reference = loaded_topic_users_reference
    @guardian = guardian || Guardian.new
    @scope = scope
    @topic_notification_levels = Set.new
  end

  FILTER_ALIASES = {
    "categories" => "category",
    "tags" => "tag",
    "groups" => "group",
    "user" => "users",
  }
  private_constant :FILTER_ALIASES

  # Shared pattern for matching quoted values (single or double quotes)
  QUOTED_VALUE_PATTERN = '"[^"]*"|\'[^\']*\''
  private_constant :QUOTED_VALUE_PATTERN

  # Pattern for extracting filter components: prefix, key, and value (supports quoted values)
  FILTER_EXTRACTION_PATTERN =
    /(?<key_prefix>(?:-|=|-=|=-))?(?<key>[\w-]+):(?<value>#{QUOTED_VALUE_PATTERN}|[^\s]+)/
  private_constant :FILTER_EXTRACTION_PATTERN

  # Pattern for tokenizing query string while preserving quoted values and filter:value pairs
  # Note: wrap QUOTED_VALUE_PATTERN in non-capturing group to preserve alternation precedence
  TOKENIZER_PATTERN =
    /[\w-]+:(?:#{QUOTED_VALUE_PATTERN})|[\w-]+:[^\s]+|(?:#{QUOTED_VALUE_PATTERN})|[^\s]+/
  private_constant :TOKENIZER_PATTERN

  def filter_from_query_string(query_string)
    return @scope if query_string.blank?

    filters = {}

    query_string.scan(FILTER_EXTRACTION_PATTERN) do |key_prefix, key, value|
      key = FILTER_ALIASES[key] || key

      filters[key] ||= {}
      filters[key]["key_prefixes"] ||= []
      filters[key]["key_prefixes"] << key_prefix
      filters[key]["values"] ||= []
      filters[key]["values"] << value
    end

    filters.each do |filter, hash|
      key_prefixes = hash["key_prefixes"]
      values = hash["values"]

      filter_values = extract_and_validate_value_for(filter, values)
      case filter
      when "activity-before"
        filter_by_activity(before: filter_values)
      when "activity-after"
        filter_by_activity(after: filter_values)
      when "category"
        filter_categories(values: key_prefixes.zip(filter_values))
      when "created-after"
        filter_by_created(after: filter_values)
      when "created-before"
        filter_by_created(before: filter_values)
      when "created-by"
        filter_created_by(names: filter_values.flat_map { |value| value.split(",") })
      when "in"
        filter_in(values: filter_values)
      when "latest-post-after"
        filter_by_latest_post(after: filter_values)
      when "latest-post-before"
        filter_by_latest_post(before: filter_values)
      when "likes-min"
        filter_by_number_of_likes(min: filter_values)
      when "likes-max"
        filter_by_number_of_likes(max: filter_values)
      when "likes-op-min"
        filter_by_number_of_likes_in_first_post(min: filter_values)
      when "likes-op-max"
        filter_by_number_of_likes_in_first_post(max: filter_values)
      when "order"
        order_by(values: filter_values)
      when "users"
        filter_users(values: key_prefixes.zip(filter_values))
      when "group"
        filter_groups(values: filter_values)
      when "posts-min"
        filter_by_number_of_posts(min: filter_values)
      when "posts-max"
        filter_by_number_of_posts(max: filter_values)
      when "posters-min"
        filter_by_number_of_posters(min: filter_values)
      when "posters-max"
        filter_by_number_of_posters(max: filter_values)
      when "status"
        filter_values.each { |status| @scope = filter_status(status: status) }
      when "tag_group"
        filter_tag_groups(values: key_prefixes.zip(filter_values))
      when "tag"
        filter_tags(values: key_prefixes.zip(filter_values))
      when "locale"
        filter_locale(values: key_prefixes.zip(filter_values))
      when "views-min"
        filter_by_number_of_views(min: filter_values)
      when "views-max"
        filter_by_number_of_views(max: filter_values)
      else
        if custom_filter = DiscoursePluginRegistry.custom_filter_mappings.find { _1.key?(filter) }
          @scope = custom_filter[filter].call(@scope, filter_values, @guardian) || @scope
        end
      end
    end

    # Tokenize while preserving quoted values, then extract keywords (non-filter terms)
    keywords =
      query_string
        .scan(TOKENIZER_PATTERN)
        .reject { |word| word.include?(":") }
        .map(&:strip)
        .reject(&:empty?)

    if keywords.present? && keywords.join(" ").length >= SiteSetting.min_search_term_length
      ts_query = Search.ts_query(term: keywords.join(" "))
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
      end
    when "public"
      @scope = @scope.joins(:category).where("NOT categories.read_restricted")
    else
      if custom_filter = TopicsFilter.custom_status_filters[status]
        @scope = custom_filter[:block].call(@scope) if custom_filter[:enabled].call
      end
    end

    @scope
  end

  def self.option_info(guardian)
    results = [
      {
        name: "category:",
        alias: "categories:",
        description: I18n.t("filter.description.category"),
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
      },
      {
        name: "activity-before:",
        description: I18n.t("filter.description.activity_before"),
        type: "date",
      },
      {
        name: "activity-after:",
        description: I18n.t("filter.description.activity_after"),
        type: "date",
      },
      {
        name: "created-before:",
        description: I18n.t("filter.description.created_before"),
        type: "date",
      },
      {
        name: "created-after:",
        description: I18n.t("filter.description.created_after"),
        priority: 1,
        type: "date",
      },
      {
        name: "created-by:",
        description: I18n.t("filter.description.created_by"),
        type: "username_group_list",
        delimiters: [{ name: ",", description: I18n.t("filter.description.created_by_multiple") }],
      },
      {
        name: "users:",
        description: I18n.t("filter.description.users"),
        type: "username",
        priority: 1,
        prefixes: [{ name: "-", description: I18n.t("filter.description.exclude_users") }],
        delimiters: [
          { name: ",", description: I18n.t("filter.description.users_any") },
          { name: "+", description: I18n.t("filter.description.users_all") },
        ],
      },
      {
        name: "latest-post-before:",
        description: I18n.t("filter.description.latest_post_before"),
        type: "date",
      },
      {
        name: "latest-post-after:",
        description: I18n.t("filter.description.latest_post_after"),
        type: "date",
      },
      { name: "likes-min:", description: I18n.t("filter.description.likes_min"), type: "number" },
      { name: "likes-max:", description: I18n.t("filter.description.likes_max"), type: "number" },
      {
        name: "likes-op-min:",
        description: I18n.t("filter.description.likes_op_min"),
        type: "number",
      },
      {
        name: "likes-op-max:",
        description: I18n.t("filter.description.likes_op_max"),
        type: "number",
      },
      { name: "posts-min:", description: I18n.t("filter.description.posts_min"), type: "number" },
      { name: "posts-max:", description: I18n.t("filter.description.posts_max"), type: "number" },
      {
        name: "posters-min:",
        description: I18n.t("filter.description.posters_min"),
        type: "number",
      },
      {
        name: "posters-max:",
        description: I18n.t("filter.description.posters_max"),
        type: "number",
      },
      { name: "views-min:", description: I18n.t("filter.description.views_min"), type: "number" },
      { name: "views-max:", description: I18n.t("filter.description.views_max"), type: "number" },
      { name: "status:", description: I18n.t("filter.description.status"), priority: 1 },
      { name: "status:open", description: I18n.t("filter.description.status_open") },
      { name: "status:closed", description: I18n.t("filter.description.status_closed") },
      { name: "status:archived", description: I18n.t("filter.description.status_archived") },
      { name: "status:listed", description: I18n.t("filter.description.status_listed") },
      { name: "status:unlisted", description: I18n.t("filter.description.status_unlisted") },
      { name: "status:deleted", description: I18n.t("filter.description.status_deleted") },
      { name: "status:public", description: I18n.t("filter.description.status_public") },
      { name: "order:", description: I18n.t("filter.description.order"), priority: 1 },
      { name: "order:activity", description: I18n.t("filter.description.order_activity") },
      { name: "order:activity-asc", description: I18n.t("filter.description.order_activity_asc") },
      { name: "order:category", description: I18n.t("filter.description.order_category") },
      { name: "order:category-asc", description: I18n.t("filter.description.order_category_asc") },
      { name: "order:created", description: I18n.t("filter.description.order_created") },
      { name: "order:created-asc", description: I18n.t("filter.description.order_created_asc") },
      { name: "order:latest-post", description: I18n.t("filter.description.order_latest_post") },
      {
        name: "order:latest-post-asc",
        description: I18n.t("filter.description.order_latest_post_asc"),
      },
      { name: "order:likes", description: I18n.t("filter.description.order_likes") },
      { name: "order:likes-asc", description: I18n.t("filter.description.order_likes_asc") },
      { name: "order:likes-op", description: I18n.t("filter.description.order_likes_op") },
      { name: "order:likes-op-asc", description: I18n.t("filter.description.order_likes_op_asc") },
      { name: "order:posters", description: I18n.t("filter.description.order_posters") },
      { name: "order:posters-asc", description: I18n.t("filter.description.order_posters_asc") },
      { name: "order:title", description: I18n.t("filter.description.order_title") },
      { name: "order:title-asc", description: I18n.t("filter.description.order_title_asc") },
      { name: "order:views", description: I18n.t("filter.description.order_views") },
      { name: "order:views-asc", description: I18n.t("filter.description.order_views_asc") },
      { name: "order:hot", description: I18n.t("filter.description.order_hot") },
      { name: "order:hot-asc", description: I18n.t("filter.description.order_hot_asc") },
      { name: "order:read", description: I18n.t("filter.description.order_read") },
      { name: "order:read-asc", description: I18n.t("filter.description.order_read_asc") },
    ]

    if guardian.authenticated?
      results.concat(
        [
          { name: "in:", description: I18n.t("filter.description.in"), priority: 1 },
          { name: "in:pinned", description: I18n.t("filter.description.in_pinned") },
          { name: "in:bookmarked", description: I18n.t("filter.description.in_bookmarked") },
          { name: "in:watching", description: I18n.t("filter.description.in_watching") },
          { name: "in:tracking", description: I18n.t("filter.description.in_tracking") },
          { name: "in:muted", description: I18n.t("filter.description.in_muted") },
          { name: "in:normal", description: I18n.t("filter.description.in_normal") },
          {
            name: "in:watching_first_post",
            description: I18n.t("filter.description.in_watching_first_post"),
          },
          { name: "in:new", description: I18n.t("filter.description.in_new") },
          { name: "in:new-replies", description: I18n.t("filter.description.in_new_replies") },
          { name: "in:new-topics", description: I18n.t("filter.description.in_new_topics") },
          { name: "in:unseen", description: I18n.t("filter.description.in_unseen") },
        ],
      )
    end

    if SiteSetting.tagging_enabled?
      results.push(
        {
          name: "tag:",
          description: I18n.t("filter.description.tag"),
          alias: "tags:",
          priority: 1,
          type: "tag",
          delimiters: [
            { name: ",", description: I18n.t("filter.description.tags_any") },
            { name: "+", description: I18n.t("filter.description.tags_all") },
          ],
          prefixes: [{ name: "-", description: I18n.t("filter.description.exclude_tag") }],
        },
      )
      results.push(
        {
          name: "tag_group:",
          description: I18n.t("filter.description.tag_group"),
          type: "tag_group",
          prefixes: [{ name: "-", description: I18n.t("filter.description.exclude_tag_group") }],
        },
      )
    end

    # Group participation filter (any/all)
    results.push(
      {
        name: "group:",
        alias: "groups:",
        description: I18n.t("filter.description.group"),
        type: "group",
        priority: 1,
        delimiters: [
          { name: ",", description: I18n.t("filter.description.groups_any") },
          { name: "+", description: I18n.t("filter.description.groups_all") },
        ],
      },
    )

    # Locale filter
    results.push(
      {
        name: "locale:",
        description: I18n.t("filter.description.locale"),
        type: "text",
        delimiters: [{ name: ",", description: I18n.t("filter.description.locale_any") }],
        prefixes: [{ name: "-", description: I18n.t("filter.description.exclude_locale") }],
      },
    )

    # this modifier allows custom plugins to add UI tips in the /filter route
    DiscoursePluginRegistry.apply_modifier(:topics_filter_options, results, guardian)
  end

  private

  YYYY_MM_DD_REGEXP =
    /\A(?<year>[12][0-9]{3})-(?<month>0?[1-9]|1[0-2])-(?<day>0?[1-9]|[12]\d|3[01])\z/
  private_constant :YYYY_MM_DD_REGEXP

  def extract_and_validate_value_for(filter, values)
    case filter
    when "activity-before", "activity-after", "created-before", "created-after",
         "latest-post-before", "latest-post-after"
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

  def filter_by_topic_range(column_name:, min: nil, max: nil, scope: nil)
    { min => ">=", max => "<=" }.each do |value, operator|
      next if !value
      @scope = (scope || @scope).where("#{column_name} #{operator} ?", value)
    end
  end

  def filter_by_activity(before: nil, after: nil)
    filter_by_topic_range(column_name: "topics.bumped_at", min: after, max: before)
  end

  def filter_by_created(before: nil, after: nil)
    filter_by_topic_range(column_name: "topics.created_at", min: after, max: before)
  end

  def filter_by_latest_post(before: nil, after: nil)
    filter_by_topic_range(column_name: "topics.last_posted_at", min: after, max: before)
  end

  def filter_by_number_of_posts(min: nil, max: nil)
    filter_by_topic_range(column_name: "topics.posts_count", min:, max:)
  end

  def filter_by_number_of_posters(min: nil, max: nil)
    filter_by_topic_range(column_name: "topics.participant_count", min:, max:)
  end

  def filter_by_number_of_likes(min: nil, max: nil)
    filter_by_topic_range(column_name: "topics.like_count", min:, max:)
  end

  def filter_by_number_of_likes_in_first_post(min: nil, max: nil)
    filter_by_topic_range(
      column_name: "first_posts.like_count",
      min:,
      max:,
      scope: self.joins_first_posts(@scope),
    )
  end

  def filter_by_number_of_views(min: nil, max: nil)
    filter_by_topic_range(column_name: "topics.views", min:, max:)
  end

  def calculate_all_or_any(value)
    require_all = nil
    names = nil

    if value.include?("+")
      names = value.split("+")
      require_all = true
      if value.include?(",")
        # no mix and match
        return nil, []
      end
    else
      names = value.split(",")
      require_all = false
      if value.include?("+")
        # no mix and match
        return nil, []
      end
    end

    [require_all, names.map(&:downcase).reject(&:blank?)]
  end

  # users:a,b => any of a or b participated in the topic
  # users:a+b => both a and b participated in the topic
  # -users:a,b => neither a nor b participated in the topic
  # -users:a+b => at least one of a or b did not participate in the topic
  def filter_users(values:)
    values.each do |prefix, value|
      require_all, usernames = calculate_all_or_any(value)

      if usernames.empty?
        @scope = @scope.none
        next
      end

      user_ids = User.not_staged.where("username_lower IN (?)", usernames).pluck(:id)

      if user_ids.empty?
        @scope = @scope.none
        next
      end

      if require_all
        if user_ids.length < usernames.length
          @scope = @scope.none
          next
        end

        # A possible alternative is to select the topics with the users with the least posts
        # then expand to all of the rest of the users, this can limit the scanning
        if prefix == "-"
          @scope = @scope.where(<<~SQL, user_ids: user_ids, user_count: user_ids.length)
            topics.id NOT IN (
              SELECT p1.topic_id
              FROM posts p1
              WHERE p1.user_id IN (:user_ids) AND p1.deleted_at IS NULL #{whisper_condition("p1")}
              GROUP BY p1.topic_id
              HAVING COUNT(DISTINCT p1.user_id) = :user_count
            )
          SQL
        else
          user_ids.each_with_index { |uid, idx| @scope = @scope.where(<<~SQL) }
            EXISTS (
              SELECT 1
              FROM posts p#{idx}
              WHERE p#{idx}.topic_id = topics.id AND p#{idx}.user_id = #{uid} AND p#{idx}.deleted_at IS NULL #{whisper_condition("p#{idx}")}
              LIMIT 1
            )
          SQL
        end
      else
        not_sql = prefix == "-" ? "NOT" : ""
        @scope = @scope.where(<<~SQL, user_ids: user_ids)
              topics.id #{not_sql} IN (
                SELECT DISTINCT p.topic_id
                FROM posts p
                WHERE p.user_id IN (:user_ids)
                  AND p.deleted_at IS NULL
                  #{whisper_condition("p")}
              )
            SQL
      end
    end
  end

  # group:staff,moderators => any of the groups have participation
  # group:staff+moderators => both groups have participation
  def filter_groups(values:)
    values.each do |value|
      require_all, group_names = calculate_all_or_any(value)

      if group_names.empty?
        @scope = @scope.none
        next
      end

      group_ids =
        Group
          .visible_groups(@guardian.user)
          .members_visible_groups(@guardian.user)
          .where("lower(name) IN (?)", group_names)
          .pluck(:id)

      if group_ids.empty?
        @scope = @scope.none
        next
      end

      if require_all
        if group_ids.length < group_names.length
          @scope = @scope.none
          next
        end

        group_ids.each_with_index { |gid, idx| @scope = @scope.where(<<~SQL) }
            EXISTS (
              SELECT 1
              FROM posts pg#{idx}
              JOIN group_users gu#{idx} ON gu#{idx}.user_id = pg#{idx}.user_id
              WHERE pg#{idx}.topic_id = topics.id AND gu#{idx}.group_id = #{gid} #{whisper_condition("pg#{idx}")}
            )
          SQL
      else
        @scope = @scope.where(<<~SQL, group_ids: group_ids)
              topics.id IN (
                SELECT DISTINCT p.topic_id
                FROM posts p
                JOIN group_users gu ON gu.user_id = p.user_id
                WHERE gu.group_id IN (:group_ids)
                  #{whisper_condition("p")}
              )
            SQL
      end
    end
  end

  def filter_categories(values:)
    category_slugs = {
      include: {
        with_subcategories: [],
        without_subcategories: [],
      },
      exclude: {
        with_subcategories: [],
        without_subcategories: [],
      },
    }

    values.each do |key_prefix, value|
      exclude_categories = key_prefix&.include?("-")
      exclude_subcategories = key_prefix&.include?("=")

      value
        .scan(
          /\A(?<category_slugs>([\p{L}\p{N}\-:]+)(?<delimiter>[,])?([\p{L}\p{N}\-:]+)?(\k<delimiter>[\p{L}\p{N}\-:]+)*)\z/,
        )
        .each do |category_slugs_match, delimiter|
          slugs = category_slugs_match.split(delimiter)
          type = exclude_categories ? :exclude : :include
          subcategory_type = exclude_subcategories ? :without_subcategories : :with_subcategories
          category_slugs[type][subcategory_type].concat(slugs)
        end
    end

    include_category_ids = []

    if category_slugs[:include][:without_subcategories].present?
      include_category_ids =
        get_category_ids_from_slugs(
          category_slugs[:include][:without_subcategories],
          exclude_subcategories: true,
        )
    end

    if category_slugs[:include][:with_subcategories].present?
      include_category_ids.concat(
        get_category_ids_from_slugs(
          category_slugs[:include][:with_subcategories],
          exclude_subcategories: false,
        ),
      )
    end

    if include_category_ids.present?
      @scope = @scope.where("topics.category_id IN (?)", include_category_ids)
    elsif category_slugs[:include].values.flatten.present?
      @scope = @scope.none
      return
    end

    exclude_category_ids = []

    if category_slugs[:exclude][:without_subcategories].present?
      exclude_category_ids =
        get_category_ids_from_slugs(
          category_slugs[:exclude][:without_subcategories],
          exclude_subcategories: true,
        )
    end

    if category_slugs[:exclude][:with_subcategories].present?
      exclude_category_ids.concat(
        get_category_ids_from_slugs(
          category_slugs[:exclude][:with_subcategories],
          exclude_subcategories: false,
        ),
      )
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
    if names.include?("me") && @guardian.authenticated?
      names = names.map { |n| n == "me" ? @guardian.user.username_lower : n }
    end

    if (user_ids = User.where("username_lower IN (?)", names.map(&:downcase)).pluck(:id)) &&
         user_ids.any?
      @scope = @scope.joins(:user).where(user_id: user_ids)
      return
    end

    if (
         group_ids =
           Group
             .visible_groups(@guardian.user)
             .members_visible_groups(@guardian.user)
             .where("lower(name) IN (?)", names.map(&:downcase))
             .pluck(:id)
       ) && group_ids.any?
      @scope =
        @scope
          .joins(:user)
          .joins("INNER JOIN group_users ON group_users.user_id = users.id")
          .where("group_users.group_id IN (?)", group_ids)
          .distinct(:id)
      return
    end

    @scope = @scope.none
  end

  def apply_custom_filter!(scope:, filter_name:, values:)
    values.dup.each do |value|
      custom_key = "#{filter_name}:#{value}"
      if custom_match =
           DiscoursePluginRegistry.custom_filter_mappings.find { |hash| hash.key?(custom_key) }
        scope = custom_match[custom_key].call(scope, custom_key, @guardian) || scope
        values.delete(value)
      end
    end
    scope
  end

  def ensure_topic_users_reference!
    if @guardian.authenticated?
      if !@loaded_topic_users_reference
        @scope =
          @scope.joins(
            "LEFT JOIN topic_users tu ON tu.topic_id = topics.id
            AND tu.user_id = #{@guardian.user.id.to_i}",
          )
        @loaded_topic_users_reference = true
      end
    end
  end

  def topic_user_scope
    @scope.where(
      "tu.notification_level IN (:topic_notification_levels)",
      topic_notification_levels: @topic_notification_levels.to_a,
    )
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

    # handle edge case of comma-separated values
    values.map! { |value| value.split(",") }.flatten!

    if values.delete("pinned")
      @scope =
        @scope.where(
          "topics.pinned_at IS NOT NULL AND topics.pinned_until > topics.pinned_at AND ? < topics.pinned_until",
          Time.zone.now,
        )
    end

    @scope = apply_custom_filter!(scope: @scope, filter_name: "in", values:)

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

      if values.present?
        values.each do |value|
          value
            .split(",")
            .each do |topic_notification_level|
              if level = TopicUser.notification_levels[topic_notification_level.to_sym]
                @topic_notification_levels << level
              end
            end
        end
      end

      # watching_first_post is a category/tag-level notification, not a topic-level one
      # We need to handle it separately from regular notification levels and combine with OR
      has_watching_first_post = values.delete("watching_first_post")

      if has_watching_first_post && @topic_notification_levels.present?
        ensure_topic_users_reference!
        @scope = combine_scopes_with_or(topic_user_scope, watching_first_post_scope)
      elsif has_watching_first_post
        @scope = @scope.merge(watching_first_post_scope)
      elsif @topic_notification_levels.present?
        ensure_topic_users_reference!
        @scope = @scope.merge(topic_user_scope)
      end
    elsif values.present?
      @scope = @scope.none
    end
  end

  def get_category_ids_from_slugs(slugs, exclude_subcategories: false)
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

  # Accepts an array of tag names and returns an array of tag ids and the tag ids of aliases for the tag names which the user can see.
  # If a block is given, it will be called with the tag ids and alias tag ids as arguments.
  def tag_ids_from_tag_names(tag_names)
    tag_ids, alias_tag_ids =
      DiscourseTagging
        .filter_visible(Tag, @guardian)
        .where_name(tag_names)
        .pluck(:id, :target_tag_id)
        .transpose

    tag_ids ||= []
    alias_tag_ids ||= []

    yield(tag_ids, alias_tag_ids) if block_given?

    all_tag_ids = tag_ids.concat(alias_tag_ids)
    all_tag_ids.compact!
    all_tag_ids.uniq!
    all_tag_ids
  end

  def filter_tag_groups(values:)
    values.each do |key_prefix, tag_groups_value|
      tag_group_name = strip_quotes(tag_groups_value)
      tag_group_ids = TagGroup.visible(@guardian).where_name(tag_group_name).pluck(:id)
      exclude_clause = "NOT" if key_prefix == "-"
      filter =
        "tags.id #{exclude_clause} IN (SELECT tag_id FROM tag_group_memberships WHERE tag_group_id IN (?))"

      query =
        if exclude_clause.present?
          @scope
            .joins("LEFT JOIN topic_tags ON topic_tags.topic_id = topics.id")
            .joins("LEFT JOIN tags ON tags.id = topic_tags.tag_id")
            .where("tags.id IS NULL OR #{filter}", tag_group_ids)
        else
          @scope.joins(:tags).where(filter, tag_group_ids)
        end

      @scope = query.distinct(:id)
    end
  end

  def strip_quotes(value)
    value.gsub(/\A["']|["']\z/, "")
  end

  def filter_tags(values:)
    return if !SiteSetting.tagging_enabled?

    values.each do |key_prefix, value|
      break if key_prefix && key_prefix != "-"

      value.scan(
        /\A(?<tag_names>([\p{N}\p{L}\-_]+)(?<delimiter>[,+])?([\p{N}\p{L}\-]+)?(\k<delimiter>[\p{N}\p{L}\-]+)*)\z/,
      ) do |tag_names, delimiter|
        match_all =
          if delimiter == ","
            false
          else
            true
          end

        tags = tag_names.split(delimiter)
        tag_ids = tag_ids_from_tag_names(tags)

        case [key_prefix, match_all]
        in ["-", false]
          exclude_topics_with_any_tags(tag_ids)
        in ["-", true]
          exclude_topics_with_all_tags(tag_ids)
        in [nil, false]
          include_topics_with_any_tags(tag_ids)
        in [nil, true]
          has_invalid_tags = tag_ids.length < tags.length

          if has_invalid_tags
            @scope = @scope.none
          else
            include_topics_with_all_tags(tag_ids)
          end
        end
      end
    end
  end

  def topic_tags_alias
    @topic_tags_alias ||= 0
    "tt#{@topic_tags_alias += 1}"
  end

  def exclude_topics_with_all_tags(tag_ids)
    where_clause = []

    tag_ids.each do |tag_id|
      sql_alias = "tt#{topic_tags_alias}"

      @scope =
        @scope.joins(
          "LEFT JOIN topic_tags #{sql_alias} ON #{sql_alias}.topic_id = topics.id AND #{sql_alias}.tag_id = #{tag_id}",
        )

      where_clause << "#{sql_alias}.topic_id IS NULL"
    end

    @scope = @scope.where(where_clause.join(" OR "))
  end

  def exclude_topics_with_any_tags(tag_ids)
    @scope =
      @scope.where(
        "topics.id NOT IN (SELECT DISTINCT topic_id FROM topic_tags WHERE topic_tags.tag_id IN (?))",
        tag_ids,
      )
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
    sql_alias = topic_tags_alias

    @scope =
      @scope
        .joins("INNER JOIN topic_tags #{sql_alias} ON #{sql_alias}.topic_id = topics.id")
        .where("#{sql_alias}.tag_id IN (?)", tag_ids)
        .distinct(:id)
  end

  def filter_locale(values:)
    include_locales = []
    exclude_locales = []

    values.each do |key_prefix, value|
      locales = value.split(",").map(&:strip).reject(&:blank?)
      next if locales.empty?

      if key_prefix == "-"
        exclude_locales.concat(locales)
      else
        include_locales.concat(locales)
      end
    end

    @scope = @scope.where(locale: include_locales) if include_locales.present?

    if exclude_locales.present?
      @scope = @scope.where("topics.locale IS NULL OR topics.locale NOT IN (?)", exclude_locales)
    end
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
      # If the order by value is not recognized, check if it is a custom filter.
      match_data = value.match(ORDER_BY_REGEXP)
      if match_data && column_name = ORDER_BY_MAPPINGS.dig(match_data[:order_by], :column)
        if scope = ORDER_BY_MAPPINGS.dig(match_data[:order_by], :scope)
          @scope = instance_exec(&scope)
        end
        @scope = @scope.order("#{column_name} #{match_data[:asc] ? "ASC" : "DESC"}")
      else
        match_data = value.match(/^(?<column>.*?)(?:-(?<asc>asc))?$/)
        key = "order:#{match_data[:column]}"
        if custom_match =
             DiscoursePluginRegistry.custom_filter_mappings.find { |hash| hash.key?(key) }
          dir = match_data[:asc] ? "ASC" : "DESC"
          @scope = custom_match[key].call(@scope, dir, @guardian) || @scope
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
