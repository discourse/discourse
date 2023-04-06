# frozen_string_literal: true

class TopicsFilter
  def initialize(guardian:, scope: Topic)
    @guardian = guardian
    @scope = scope
  end

  def filter_from_query_string(query_string)
    return @scope if query_string.blank?
    category_or_clause = false

    query_string.scan(
      /(?<key_prefix>[-=])?(?<key>\w+):(?<value>[^\s]+)/,
    ) do |key_prefix, key, value|
      case key
      when "in"
        @scope = filter_state(state: value)
      when "status"
        @scope = filter_status(status: value)
      when "tags"
        value.scan(
          /^(?<tag_names>([a-zA-Z0-9\-]+)(?<delimiter>[,+])?([a-zA-Z0-9\-]+)?(\k<delimiter>[a-zA-Z0-9\-]+)*)$/,
        ) do |tag_names, delimiter|
          break if key_prefix && key_prefix != "-"

          match_all =
            if delimiter == ","
              false
            else
              true
            end

          @scope =
            filter_tags(
              tag_names: tag_names.split(delimiter),
              exclude: key_prefix.presence,
              match_all: match_all,
            )
        end
      when "category", "categories"
        value.scan(
          /^(?<category_slugs>([a-zA-Z0-9\-:]+)(?<delimiter>[,])?([a-zA-Z0-9\-:]+)?(\k<delimiter>[a-zA-Z0-9\-:]+)*)$/,
        ) do |category_slugs, delimiter|
          break if key_prefix && key_prefix != "="

          @scope =
            filter_categories(
              category_slugs: category_slugs.split(delimiter),
              exclude_subcategories: key_prefix.presence,
              or_clause: category_or_clause,
            )

          category_or_clause = true
        end
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

  def filter_state(state:)
    case state
    when "pinned"
      @scope.where(
        "topics.pinned_at IS NOT NULL AND topics.pinned_until > topics.pinned_at AND ? < topics.pinned_until",
        Time.zone.now,
      )
    else
      @scope
    end
  end

  def filter_categories(category_slugs:, exclude_subcategories: false, or_clause: false)
    category_ids = Category.ids_from_slugs(category_slugs)

    category_ids =
      Category
        .where(id: category_ids)
        .filter { |category| @guardian.can_see_category?(category) }
        .map(&:id)

    # Don't return any records if the user does not have access to any of the categories
    return @scope.none if category_ids.length < category_slugs.length

    if !exclude_subcategories
      category_ids = category_ids.flat_map { |category_id| Category.subcategory_ids(category_id) }
    end

    if or_clause
      @scope.or(Topic.where("categories.id IN (?)", category_ids))
    else
      @scope.joins(:category).where("categories.id IN (?)", category_ids)
    end
  end

  def filter_tags(tag_names:, match_all: true, exclude: false)
    return @scope if !SiteSetting.tagging_enabled?
    return @scope if tag_names.blank?

    tag_ids =
      DiscourseTagging
        .filter_visible(Tag, @guardian)
        .where_name(tag_names)
        .pluck(:id, :target_tag_id)

    tag_ids.flatten!
    tag_ids.uniq!
    tag_ids.compact!

    return @scope.none if match_all && tag_ids.length != tag_names.length
    return @scope if tag_ids.empty?

    self.send(
      "#{exclude ? "exclude" : "include"}_topics_with_#{match_all ? "all" : "any"}_tags",
      tag_ids,
    )

    @scope
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
      sql_alias = "tt#{topic_tags_alias}"

      @scope =
        @scope.joins(
          "INNER JOIN topic_tags #{sql_alias} ON #{sql_alias}.topic_id = topics.id AND #{sql_alias}.tag_id = #{tag_id}",
        )
    end
  end

  def include_topics_with_any_tags(tag_ids)
    @scope = @scope.joins(:topic_tags).where("topic_tags.tag_id IN (?)", tag_ids).distinct(:id)
  end
end
