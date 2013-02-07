class UserSearch

  def self.search term, topic_id
    sql = "select username, name, email from users u "
    if topic_id
      sql << "left join (select distinct p.user_id from posts p where topic_id = :topic_id) s on
        s.user_id = u.id "
    end

    if term.length > 0
      sql << "where username_lower like :term_like or
              to_tsvector('simple', name) @@
              to_tsquery('simple',
                regexp_replace(
                  regexp_replace(
                    cast(plainto_tsquery(:term) as text)
                    ,'\''(?: |$)', ':*''', 'g'),
                '''', '', 'g')
              ) "

    end

    sql << "order by case when username_lower = :term then 0 else 1 end asc, "
    if topic_id
      sql << " case when s.user_id is null then 0 else 1 end desc, "
    end

    sql << " case when last_seen_at is null then 0 else 1 end desc, last_seen_at desc, username asc limit(20)"

    results = User.exec_sql(sql, topic_id: topic_id, term_like: "#{term}%", term: term)
    results = results.map do |r|
      r["avatar_template"] = User.avatar_template(r["email"])
      r.delete("email")
      r
    end
  end

end