# Searches for a user by username or full text or name (if enabled in SiteSettings)
class UserSearch

  def initialize(term, opts={})
    @term = term
    @term_like = "#{term.downcase}%"
    @topic_id = opts[:topic_id]
    @searching_user = opts[:searching_user]
    @limit = opts[:limit] || 20
  end

  def search
    users = User.order(User.sql_fragment("CASE WHEN username_lower = ? THEN 0 ELSE 1 END ASC", @term.downcase))

    if @term.present?
      if SiteSetting.enable_names?
        query = Search.ts_query(@term, "simple")
        users = users.includes(:user_search_data)
                     .references(:user_search_data)
                     .where("username_lower LIKE :term_like OR user_search_data.search_data @@ #{query}",
                            term: @term, term_like: @term_like)
                     .order(User.sql_fragment("CASE WHEN username_lower LIKE ? THEN 0 ELSE 1 END ASC", @term_like))
      else
        users = users.where("username_lower LIKE :term_like", term_like: @term_like)
      end
    end

    if @topic_id
      users = users.joins(User.sql_fragment("LEFT JOIN (SELECT DISTINCT p.user_id FROM POSTS p WHERE topic_id = ?) s ON s.user_id = users.id", @topic_id))
                   .order("CASE WHEN s.user_id IS NULL THEN 0 ELSE 1 END DESC")
    end

    unless @searching_user && @searching_user.staff?
      users = users.not_suspended
    end

    users.order("CASE WHEN last_seen_at IS NULL THEN 0 ELSE 1 END DESC, last_seen_at DESC, username ASC")
         .limit(@limit)
  end

end
