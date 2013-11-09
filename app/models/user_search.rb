# Searches for a user by username or full text or name (if enabled in SiteSettings)
class UserSearch

  def initialize(term, topic_id=nil)
    @term = term
    @term_like = "#{term.downcase}%"
    @topic_id = topic_id
  end

  def search
    users = User.order(User.sql_fragment("CASE WHEN username_lower = ? THEN 0 ELSE 1 END ASC", :term))

    if @term.present?
      if SiteSetting.enable_names?
        users = users.where("username_lower LIKE :term_like OR
                            TO_TSVECTOR('simple', name) @@
                            TO_TSQUERY('simple',
                              REGEXP_REPLACE(
                                REGEXP_REPLACE(
                                  CAST(PLAINTO_TSQUERY(:term) AS TEXT)
                                  ,'\''(?: |$)', ':*''', 'g'),
                              '''', '', 'g')
                            )", term: @term, term_like: @term_like)
      else
        users = users.where("username_lower LIKE :term_like", term_like: @term_like)
      end
    end

    if @topic_id
      users = users.joins(User.sql_fragment("LEFT JOIN (SELECT DISTINCT p.user_id FROM POSTS p WHERE topic_id = ?) s ON s.user_id = users.id", @topic_id))
                   .order("CASE WHEN s.user_id IS NULL THEN 0 ELSE 1 END DESC")
    end

    users.order("CASE WHEN last_seen_at IS NULL THEN 0 ELSE 1 END DESC, last_seen_at DESC, username ASC")
         .limit(20)
  end

end
