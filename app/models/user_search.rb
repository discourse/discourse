# frozen_string_literal: true

class UserSearch
  MAX_SIZE_PRIORITY_MENTION = 500

  def initialize(term, opts = {})
    @term = term.downcase
    # escape LIKE wildcards (`_`, `%`, `\`) so the term matches literally
    @term_like = ActiveRecord::Base.sanitize_sql_like(@term) + "%"
    @topic_id = opts[:topic_id]
    @category_id = opts[:category_id]
    # prioritized_user_id is only used for ordering within the topic, it will prioritize this user
    @prioritized_user_id = opts[:prioritized_user_id]
    @topic_allowed_users = opts[:topic_allowed_users]
    @searching_user = opts[:searching_user]
    @include_staged_users = opts[:include_staged_users] || false
    @last_seen_users = opts[:last_seen_users] || false
    @limit = opts[:limit] || 20
    @groups = opts[:groups]
    @can_review = opts[:can_review] || false
    @search_custom_fields = opts[:search_custom_fields] || false

    @topic = Topic.find(@topic_id) if @topic_id
    @category = Category.find(@category_id) if @category_id

    @guardian = Guardian.new(@searching_user)
    @groups&.each { |group| @guardian.ensure_can_see_group_and_members!(group) }
    @guardian.ensure_can_see_category!(@category) if @category
    @guardian.ensure_can_see_topic!(@topic) if @topic
  end

  def scoped_users
    users = User.where(active: true)
    users = users.where(approved: true) if SiteSetting.must_approve_users?
    users = users.where(staged: false) unless @include_staged_users
    users = users.not_suspended unless @searching_user&.staff?

    if @groups
      users = users.joins(:group_users).where("group_users.group_id IN (?)", @groups.map(&:id))
    end

    if @can_review
      if SiteSetting.enable_category_group_moderation?
        category_moderator_group_ids = CategoryModerationGroup.distinct.pluck(:group_id)
        users =
          users.left_joins(:group_users).where(
            "users.admin OR users.moderator OR group_users.group_id IN (?)",
            category_moderator_group_ids,
          )
      else
        users = users.merge(User.staff)
      end
    end

    # Only show users who have access to private topic
    if @topic_allowed_users == "true" && @topic&.category&.read_restricted
      users =
        users
          .references(:categories)
          .includes(:secure_categories)
          .where("users.admin OR categories.id = ?", @topic.category_id)
    end

    users
  end

  def filtered_by_term_users
    if @term.blank?
      scoped_users
    elsif @search_custom_fields
      # Directory search: also match searchable custom field values, even with
      # names disabled or `_`, `.`, `-` terms. See `tsvector_filtered_users`.
      tsvector_filtered_users(weight_filter: SiteSetting.enable_names? ? nil : "AC")
    elsif SiteSetting.enable_names? && @term !~ /[_.-]/
      tsvector_filtered_users
    else
      scoped_users.where("username_lower LIKE ?", @term_like)
    end
  end

  def search_ids
    users = Set.new

    # 1. exact username matches
    if @term.present?
      exact_matches = scoped_users.where(username_lower: @term)

      # don't pollute mentions with users who haven't shown up in over a year
      exact_matches = exact_matches.where("last_seen_at > ?", 1.year.ago) if @topic_id ||
        @category_id

      exact_matches.limit(@limit).pluck(:id).each { |id| users << id }
    end

    return users.to_a if users.size >= @limit

    # 2. in topic
    if @topic_id
      in_topic =
        filtered_by_term_users.where(
          "users.id IN (SELECT user_id FROM posts WHERE topic_id = ? AND post_type = ? AND deleted_at IS NULL)",
          @topic_id,
          Post.types[:regular],
        )

      in_topic = in_topic.where.not(users: { id: @searching_user.id }) if @searching_user.present?

      if @prioritized_user_id
        in_topic =
          in_topic.order(
            DB.sql_fragment("CASE WHEN users.id = ? THEN 0 ELSE 1 END", @prioritized_user_id),
          )
      end

      in_topic
        .order("last_seen_at DESC NULLS LAST")
        .limit(@limit - users.size)
        .pluck(:id)
        .each { |id| users << id }
    end

    return users.to_a if users.size >= @limit

    # 3. in category
    secure_category_id =
      if @category_id
        DB.query_single(<<~SQL, @category_id).first
          SELECT id
            FROM categories
           WHERE read_restricted
             AND id = ?
        SQL
      elsif @topic_id
        DB.query_single(<<~SQL, @topic_id).first
          SELECT id
            FROM categories
           WHERE read_restricted
             AND id IN (SELECT category_id FROM topics WHERE id = ?)
        SQL
      end

    if secure_category_id
      category_groups = Group.where(<<~SQL, secure_category_id, MAX_SIZE_PRIORITY_MENTION)
        groups.id IN (
          SELECT group_id
            FROM category_groups
            JOIN groups g ON group_id = g.id
           WHERE category_id = ?
             AND user_count < ?
        )
      SQL

      if @searching_user.present?
        category_groups = category_groups.members_visible_groups(@searching_user)
      end

      in_category = filtered_by_term_users.where(<<~SQL, category_groups.pluck(:id))
          users.id IN (
            SELECT gu.user_id
              FROM group_users gu
             WHERE group_id IN (?)
             LIMIT 200
          )
          SQL

      if @searching_user.present?
        in_category = in_category.where.not(users: { id: @searching_user.id })
      end

      in_category
        .order("last_seen_at DESC NULLS LAST")
        .limit(@limit - users.size)
        .pluck(:id)
        .each { |id| users << id }
    end

    return users.to_a if users.size >= @limit

    # 4. global matches
    if @term.present?
      filtered_by_term_users
        .order("last_seen_at DESC NULLS LAST")
        .limit(@limit - users.size)
        .pluck(:id)
        .each { |id| users << id }
    end

    return users.to_a if users.size >= @limit

    # 5. last seen users (for search auto-suggestions)
    if @last_seen_users
      scoped_users
        .order("last_seen_at DESC NULLS LAST")
        .limit(@limit - users.size)
        .pluck(:id)
        .each { |id| users << id }
    end

    users.to_a
  end

  def search
    ids = search_ids
    ids = DiscoursePluginRegistry.apply_modifier(:user_search_ids, ids)
    return User.none if ids.empty?

    results =
      User.joins(
        "JOIN (SELECT unnest uid, row_number() OVER () AS rn
      FROM unnest('{#{ids.join(",")}}'::int[])
    ) x on uid = users.id",
      ).order("rn")

    results = results.includes(:user_option)
    results = results.includes(:user_status) if SiteSetting.enable_user_status

    results
  end

  private

  # Filters `scoped_users` by matching `@term` against the `user_search_data`
  # tsvector (A = username, B = name, C = searchable custom fields). Pass
  # `weight_filter: "AC"` to skip the name (B) weight when names are disabled,
  # mirroring `Search#user_search`. Usernames match via the A weight; the
  # `simple` config tokenises the query the same way it indexed the username, so
  # no separate `username_lower LIKE` clause is needed (see `Search#user_search`).
  def tsvector_filtered_users(weight_filter: nil)
    query = Search.ts_query(term: @term, ts_config: "simple", weight_filter:)

    scoped_users
      .includes(:user_search_data)
      .references(:user_search_data)
      .where("user_search_data.search_data @@ #{query}")
      .order(DB.sql_fragment("CASE WHEN username_lower LIKE ? THEN 0 ELSE 1 END ASC", @term_like))
  end
end
