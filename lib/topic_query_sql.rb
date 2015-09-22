#
#  SQL fragments used when querying a list of topics.
#
module TopicQuerySQL

  class << self

    def lowest_date
      "1900-01-01"
    end

    def order_by_category_sql(dir)
      "CASE WHEN categories.id = #{SiteSetting.uncategorized_category_id.to_i} THEN '' ELSE categories.name END #{dir}"
    end

    # If you've clearned the pin, use bumped_at, otherwise put it at the top
    def order_with_pinned_sql
      "CASE
        WHEN (COALESCE(topics.pinned_at, '#{lowest_date}') > COALESCE(tu.cleared_pinned_at, '#{lowest_date}'))
          THEN topics.pinned_at + interval '9999 years'
          ELSE topics.bumped_at
       END DESC"
    end

    # If you've clearned the pin, use bumped_at, otherwise put it at the top
    def order_nocategory_with_pinned_sql
      "CASE
        WHEN topics.pinned_globally
         AND (COALESCE(topics.pinned_at, '#{lowest_date}') > COALESCE(tu.cleared_pinned_at, '#{lowest_date}'))
          THEN topics.pinned_at + interval '9999 years'
          ELSE topics.bumped_at
       END DESC"
    end

    def order_basic_bumped
      "CASE WHEN (topics.pinned_at IS NOT NULL) THEN 0 ELSE 1 END, topics.bumped_at DESC"
    end

    def order_nocategory_basic_bumped
      "CASE WHEN topics.pinned_globally AND (topics.pinned_at IS NOT NULL) THEN 0 ELSE 1 END, topics.bumped_at DESC"
    end

    def order_top_for(score)
      "COALESCE(top_topics.#{score}, 0) DESC, topics.bumped_at DESC"
    end

    def order_top_with_pinned_category_for(score)
      # display pinned topics first
      "CASE WHEN (COALESCE(topics.pinned_at, '#{lowest_date}') > COALESCE(tu.cleared_pinned_at, '#{lowest_date}')) THEN 0 ELSE 1 END,
       top_topics.#{score} DESC,
       topics.bumped_at DESC"
    end

    def boring_qualifications_query(user_or_id)
      boring_qualifications(user_or_id).join("\nUNION ALL\n")
    end

    def boring_qualifications(user_or_id)
      user_id = Fixnum === user_or_id ? user_or_id : user_or_id.id # allow record or id
      [boring_flag_pms_query, welcome_messages_query(user_id)]
    end

    def boring_flag_pms_query
      <<SQL
  SELECT t2.id id
  FROM post_actions pa
  INNER JOIN posts p ON p.id = pa.related_post_id
  INNER JOIN topics t2 ON p.topic_id = t2.id
  LEFT OUTER JOIN posts p2 ON p2.topic_id = p.topic_id AND p2.post_number = 2
  WHERE pa.related_post_id IS NOT NULL
  AND (t2.posts_count = 1 OR (
    t2.posts_count = 2 AND p2.post_type = 2
  ))
SQL
    end

    def welcome_messages_query(user_id)
      sql = <<SQL
  SELECT t3.id id
  FROM topics t3
  WHERE t3.title LIKE ?
  AND t3.posts_count = 1
  AND t3.user_id = ?
SQL
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, I18n.t('system_messages.welcome_user.subject_template', site_name: '%'), user_id])
    end
  end
end
