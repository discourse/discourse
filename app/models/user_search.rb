# Searches for a user by username or full text or name (if enabled in SiteSettings)
require_dependency 'search'

class UserSearch

  def initialize(term, opts = {})
    @term = term
    @term_like = "#{term.downcase.gsub("_", "\\_")}%"
    @topic_id = opts[:topic_id]
    @topic_allowed_users = opts[:topic_allowed_users]
    @searching_user = opts[:searching_user]
    @include_staged_users = opts[:include_staged_users] || false
    @limit = opts[:limit] || 20
    @group = opts[:group]
    @guardian = Guardian.new(@searching_user)
    @guardian.ensure_can_see_group!(@group) if @group
  end

  def scoped_users
    users = User.where(active: true)
    users = users.where(staged: false) unless @include_staged_users

    if @group
      users = users.where('users.id IN (
        SELECT user_id FROM group_users WHERE group_id = ?
      )', @group.id)
    end

    unless @searching_user && @searching_user.staff?
      users = users.not_suspended
    end

    # Only show users who have access to private topic
    if @topic_id && @topic_allowed_users == "true"
      topic = Topic.find_by(id: @topic_id)

      if topic.category && topic.category.read_restricted
        users = users.includes(:secure_categories)
          .where("users.admin = TRUE OR categories.id = ?", topic.category.id)
          .references(:categories)
      end
    end

    users.limit(@limit)
  end

  def filtered_by_term_users
    users = scoped_users

    if @term.present?
      if SiteSetting.enable_names? && @term !~ /[_\.-]/
        query = Search.ts_query(term: @term, ts_config: "simple")

        users = users.includes(:user_search_data)
          .references(:user_search_data)
          .where("user_search_data.search_data @@ #{query}")
          .order(DB.sql_fragment("CASE WHEN username_lower LIKE ? THEN 0 ELSE 1 END ASC", @term_like))

      else
        users = users.where("username_lower LIKE :term_like", term_like: @term_like)
      end
    end

    users
  end

  def search_ids
    users = Set.new

    # 1. exact username matches
    if @term.present?
      scoped_users.where(username_lower: @term.downcase)
        .limit(@limit)
        .pluck(:id)
        .each { |id| users << id }

    end

    return users.to_a if users.length >= @limit

    # 2. in topic
    if @topic_id
      filtered_by_term_users.where('users.id IN (SELECT p.user_id FROM posts p WHERE topic_id = ?)', @topic_id)
        .order('last_seen_at DESC')
        .limit(@limit - users.length)
        .pluck(:id)
        .each { |id| users << id }
    end

    return users.to_a if users.length >= @limit

    # 3. global matches
    filtered_by_term_users.order('last_seen_at DESC')
      .limit(@limit - users.length)
      .pluck(:id)
      .each { |id| users << id }

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
