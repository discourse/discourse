# frozen_string_literal: true

class TopicsFilter
  attr_reader :topic_notification_levels

  def initialize(guardian:, scope: Topic.all)
    @guardian = guardian
    @scope = scope
    @topic_notification_levels = Set.new
  end

  FILTER_ALIASES = { "categories" => "category", "tags" => "tag" }
  private_constant :FILTER_ALIASES

  def filter_from_query_string(query_string)
    return @scope if query_string.blank?

    filters = {}

    query_string.scan(
      /(?<key_prefix>[-=])?(?<key>[\w-]+):(?<value>[^\s]+)/,
    ) do |key_prefix, key, value|
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
        filter_created_by_user(usernames: filter_values.flat_map { |value| value.split(",") })
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
      when "tag"
        filter_tags(values: key_prefixes.zip(filter_values))
      when "views-min"
        filter_by_number_of_views(min: filter_values)
      when "views-max"
        filter_by_number_of_views(max: filter_values)
      end
    end

    @scope
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
        @scope = @scope.unscope(where: :deleted_at).where("topics.deleted_at IS NOT NULL")
      end
    when "public"
      @scope = @scope.joins(:category).where("NOT categories.read_restricted")
    end

    @scope
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
    filter_by_topic_range(column_name: "views", min:, max:)
  end

  def filter_categories(values:)
    exclude_subcategories_category_slugs = []
    include_subcategories_category_slugs = []

    values.each do |key_prefix, value|
      break if key_prefix && key_prefix != "="

      value
        .scan(
          /\A(?<category_slugs>([a-zA-Z0-9\-:]+)(?<delimiter>[,])?([a-zA-Z0-9\-:]+)?(\k<delimiter>[a-zA-Z0-9\-:]+)*)\z/,
        )
        .each do |category_slugs, delimiter|
          (
            if key_prefix.presence
              exclude_subcategories_category_slugs
            else
              include_subcategories_category_slugs
            end
          ).concat(category_slugs.split(delimiter))
        end
    end

    category_ids = []

    if exclude_subcategories_category_slugs.present?
      category_ids =
        get_category_ids_from_slugs(
          exclude_subcategories_category_slugs,
          exclude_subcategories: true,
        )
    end

    if include_subcategories_category_slugs.present?
      category_ids.concat(
        get_category_ids_from_slugs(
          include_subcategories_category_slugs,
          exclude_subcategories: false,
        ),
      )
    end

    if category_ids.present?
      @scope = @scope.where("topics.category_id IN (?)", category_ids)
    elsif exclude_subcategories_category_slugs.present? ||
          include_subcategories_category_slugs.present?
      @scope = @scope.none
    end
  end

  def filter_created_by_user(usernames:)
    @scope =
      @scope.joins(:user).where(
        "users.username_lower IN (:usernames)",
        usernames: usernames.map(&:downcase),
      )
  end

  def filter_in(values:)
    values.uniq!

    if values.delete("pinned")
      @scope =
        @scope.where(
          "topics.pinned_at IS NOT NULL AND topics.pinned_until > topics.pinned_at AND ? < topics.pinned_until",
          Time.zone.now,
        )
    end

    if @guardian.user
      if values.delete("bookmarked")
        @scope =
          @scope.joins(:topic_users).where(
            "topic_users.bookmarked AND topic_users.user_id = ?",
            @guardian.user.id,
          )
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

        @scope =
          @scope.joins(:topic_users).where(
            "topic_users.notification_level IN (:topic_notification_levels) AND topic_users.user_id = :user_id",
            topic_notification_levels: @topic_notification_levels.to_a,
            user_id: @guardian.user.id,
          )
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

  def filter_tags(values:)
    return if !SiteSetting.tagging_enabled?

    exclude_all_tags = []
    exclude_any_tags = []
    include_any_tags = []
    include_all_tags = []

    values.each do |key_prefix, value|
      break if key_prefix && key_prefix != "-"

      value.scan(
        /\A(?<tag_names>([\p{N}\p{L}\-]+)(?<delimiter>[,+])?([\p{N}\p{L}\-]+)?(\k<delimiter>[\p{N}\p{L}\-]+)*)\z/,
      ) do |tag_names, delimiter|
        match_all =
          if delimiter == ","
            false
          else
            true
          end

        (
          case [key_prefix, match_all]
          in ["-", true]
            exclude_all_tags
          in ["-", false]
            exclude_any_tags
          in [nil, true]
            include_all_tags
          in [nil, false]
            include_any_tags
          end
        ).concat(tag_names.split(delimiter))
      end
    end

    if exclude_all_tags.present?
      exclude_topics_with_all_tags(tag_ids_from_tag_names(exclude_all_tags))
    end

    if exclude_any_tags.present?
      exclude_topics_with_any_tags(tag_ids_from_tag_names(exclude_any_tags))
    end

    if include_any_tags.present?
      include_topics_with_any_tags(tag_ids_from_tag_names(include_any_tags))
    end

    if include_all_tags.present?
      has_invalid_tags = false

      all_tag_ids =
        tag_ids_from_tag_names(include_all_tags) do |tag_ids, _|
          has_invalid_tags = tag_ids.length < include_all_tags.length
        end

      if has_invalid_tags
        @scope = @scope.none
      else
        include_topics_with_all_tags(all_tag_ids)
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
    "views" => {
      column: "topics.views",
    },
  }
  private_constant :ORDER_BY_MAPPINGS

  ORDER_BY_REGEXP = /\A(?<order_by>#{ORDER_BY_MAPPINGS.keys.join("|")})(?<asc>-asc)?\z/
  private_constant :ORDER_BY_REGEXP

  def order_by(values:)
    values.each do |value|
      match_data = value.match(ORDER_BY_REGEXP)

      if match_data && column_name = ORDER_BY_MAPPINGS.dig(match_data[:order_by], :column)
        if scope = ORDER_BY_MAPPINGS.dig(match_data[:order_by], :scope)
          @scope = instance_exec(&scope)
        end

        @scope = @scope.order(column_name => match_data[:asc] ? :asc : :desc)
      end
    end
  end

  def joins_first_posts(scope)
    scope.joins(
      "INNER JOIN posts AS first_posts ON first_posts.topic_id = topics.id AND first_posts.post_number = 1",
    )
  end
end
