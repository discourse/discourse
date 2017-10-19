# Searches for a user by username or full text or name (if enabled in SiteSettings)
require_dependency 'search'

class UserSearch

  def initialize(term, opts = {})
    @term = term
    @term_like = "#{term.downcase.gsub("_", "\\_")}%"
    @name_query = prepare_query
    @topic_id = opts[:topic_id]
    @topic_allowed_users = opts[:topic_allowed_users]
    @searching_user = opts[:searching_user]
    @limit = opts[:limit] || 20
    @group = opts[:group]
    @guardian = Guardian.new(@searching_user)
    @guardian.ensure_can_see_group!(@group) if @group
  end

  def scoped_users
    users = User.where(active: true, staged: false)

    if @group
      users = users.where(id: group_user_subquery(@group.id))
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

    users
  end

  def prepare_query
    if SiteSetting.enable_names? && @term !~ /[_\.-]/
      term = Search.prepare_data(@term)
      ts_config, query = Search.prepare_ts_query(term, Search.ts_config)
      Arel::Nodes::NamedFunction.new('TO_TSQUERY', [
        arel_wrap(ts_config),
        Arel::Nodes.build_quoted(query)
      ], 'query')
    end
  end

  def filtered_by_term_users
    if @term.present?
      if @name_query
        scoped_users
          .joins(:user_search_data)
          .merge(name_full_text_search)
          .order(order_name_full_text_search)
      else
        scoped_users.where("username_lower LIKE :term_like", term_like: @term_like)
      end
    else
      scoped_users
    end
  end

  def search_ids
    user_ids = Set.new
    limit = @limit

    if limit > 0
      match_exact_username(limit).tap do |us|
        user_ids.merge(us)
        limit -= us.length
      end
    end
    if limit > 0
      match_user_in_topic(limit).tap do |us|
        user_ids.merge(us)
        limit -= us.length
      end
    end
    if limit > 0
      match_user_globally(limit).tap do |us|
        user_ids.merge(us)
        limit -= us.length
      end
    end

    user_ids.to_a
  end

  def match_exact_username(limit)
    if @term.present?
      scoped_users.where(username_lower: @term.downcase).limit(limit).pluck(:id)
    else
      []
    end
  end

  def match_user_in_topic(limit)
    if @topic_id
      filtered_by_term_users.where('users.id IN (SELECT p.user_id FROM posts p WHERE topic_id = ?)', @topic_id)
        .order('last_seen_at DESC')
        .limit(limit)
        .pluck(:id)
    else
      []
    end
  end

  def match_user_globally(limit)
    filtered_by_term_users.order('last_seen_at DESC')
      .limit(limit)
      .pluck(:id)
  end

  def search
    ids = search_ids
    return ids if ids.empty?

    User.joins("JOIN (SELECT unnest uid, row_number() OVER () AS rn
      FROM unnest('{#{ids.join(",")}}'::int[])
    ) x on uid = users.id")
      .order("rn")
  end

  def group_user_subquery(group_id)
    GroupUser.where(group_id: group_id)
  end

  def arel_wrap(sql_string)
    Arel::Nodes::Grouping.new(Arel.sql(sql_string))
  end

  def rank
    arel_wrap(tsearch_rank)
  end

  def tsearch_rank
    Arel::Nodes::NamedFunction.new("ts_rank_cd", [
      arel_wrap('user_search_data.search_data'),
      arel_wrap('query'),
      0 # ignores the document length
    ], 'rank')
  end

  def name_full_text_search
    UserSearchData.select(tsearch_rank).from(@name_query)
  end

  def order_name_full_text_search
    users = Arel::Table.new(:users)
    Arel::Nodes::Case.new
      .when(users[:username_lower].matches(@term_like)).then(users[:username_lower])
      .else(arel_wrap('rank'))
      .desc
  end
end
