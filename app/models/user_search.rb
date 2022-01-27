# frozen_string_literal: true

class UserSearch

  MAX_SIZE_PRIORITY_MENTION ||= 500

  def initialize(term, opts = {})
    @term = term.downcase
    @term_like = @term.gsub("_", "\\_") + "%"
    @topic_id = opts[:topic_id]
    @category_id = opts[:category_id]
    @topic_allowed_users = opts[:topic_allowed_users]
    @searching_user = opts[:searching_user]
    @include_staged_users = opts[:include_staged_users] || false
    @last_seen_users = opts[:last_seen_users] || false
    @limit = opts[:limit] || 20
    @groups = opts[:groups]

    @topic = Topic.find(@topic_id) if @topic_id
    @category = Category.find(@category_id) if @category_id

    @guardian = Guardian.new(@searching_user)
    @guardian.ensure_can_see_groups_members!(@groups) if @groups
    @guardian.ensure_can_see_category!(@category) if @category
    @guardian.ensure_can_see_topic!(@topic) if @topic
  end

  def scoped_users
    users = User.where(active: true)
    users = users.where(staged: false) unless @include_staged_users
    users = users.not_suspended unless @searching_user&.staff?

    if @groups
      users = users
        .joins(:group_users)
        .where("group_users.group_id IN (?)", @groups.map(&:id))
    end

    # Only show users who have access to private topic
    if @topic_allowed_users == "true" && @topic&.category&.read_restricted
      users = users
        .references(:categories)
        .includes(:secure_categories)
        .where("users.admin OR categories.id = ?", @topic.category_id)
    end

    users
  end

  def filtered_by_term_users
    if @term.blank?
      scoped_users
    elsif SiteSetting.enable_names? && @term !~ /[_\.-]/
      query = Search.ts_query(term: @term, ts_config: "simple")

      scoped_users
        .includes(:user_search_data)
        .where("user_search_data.search_data @@ #{query}")
        .order(DB.sql_fragment("CASE WHEN username_lower LIKE ? THEN 0 ELSE 1 END ASC", @term_like))
    else
      scoped_users.where("username_lower LIKE :term_like", term_like: @term_like)
    end
  end

  def search_ids
    users = Set.new

    # 1. exact username matches
    if @term.present?
      exact_matches = scoped_users.where(username_lower: @term)

      # don't pollute mentions with users who haven't shown up in over a year
      exact_matches = exact_matches.where('last_seen_at > ?', 1.year.ago) if @topic_id || @category_id

      exact_matches
        .limit(@limit)
        .pluck(:id)
        .each { |id| users << id }
    end

    return users.to_a if users.size >= @limit

    # 2. in topic
    if @topic_id
      in_topic = filtered_by_term_users
        .where('users.id IN (SELECT user_id FROM posts WHERE topic_id = ? AND post_type = ? AND deleted_at IS NULL)', @topic_id, Post.types[:regular])

      if @searching_user.present?
        in_topic = in_topic.where('users.id <> ?', @searching_user.id)
      end

      in_topic
        .order('last_seen_at DESC NULLS LAST')
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

      in_category = filtered_by_term_users
        .where(<<~SQL, category_groups.pluck(:id))
          users.id IN (
            SELECT gu.user_id
              FROM group_users gu
             WHERE group_id IN (?)
             LIMIT 200
          )
          SQL

      if @searching_user.present?
        in_category = in_category.where('users.id <> ?', @searching_user.id)
      end

      in_category
        .order('last_seen_at DESC NULLS LAST')
        .limit(@limit - users.size)
        .pluck(:id)
        .each { |id| users << id }
    end

    return users.to_a if users.size >= @limit

    # 4. global matches
    if @term.present?
      filtered_by_term_users
        .order('last_seen_at DESC NULLS LAST')
        .limit(@limit - users.size)
        .pluck(:id)
        .each { |id| users << id }
    end

    # 5. last seen users (for search auto-suggestions)
    if @last_seen_users
      scoped_users
        .order('last_seen_at DESC NULLS LAST')
        .limit(@limit - users.size)
        .pluck(:id)
        .each { |id| users << id }
    end

    users.to_a
  end

  def search
    ids = search_ids
    return User.where("0=1") if ids.empty?

    User.joins("JOIN (SELECT unnest uid, row_number() OVER () AS rn
      FROM unnest('{#{ids.join(",")}}'::int[])
    ) x on uid = users.id")
      .order("rn")
  end

end
