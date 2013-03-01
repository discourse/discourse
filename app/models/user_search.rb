class UserSearch
  def self.search term, topic_id = nil
    sql = User.sql_builder(
"select id, username, name, email from users u
/*left_join*/
/*where*/
/*order_by*/")


    if topic_id
      sql.left_join "(select distinct p.user_id from posts p where topic_id = :topic_id) s on s.user_id = u.id", topic_id: topic_id
    end

    if term.present?
      sql.where("username_lower like :term_like or
              to_tsvector('simple', name) @@
              to_tsquery('simple',
                regexp_replace(
                  regexp_replace(
                    cast(plainto_tsquery(:term) as text)
                    ,'\''(?: |$)', ':*''', 'g'),
                '''', '', 'g')
              )", term: term, term_like: "#{term.downcase}%")

      sql.order_by "case when username_lower = :term then 0 else 1 end asc"
    end

    if topic_id
      sql.order_by "case when s.user_id is null then 0 else 1 end desc"
    end

    sql.order_by "case when last_seen_at is null then 0 else 1 end desc, last_seen_at desc, username asc limit(20)"

    sql.exec
  end
end
