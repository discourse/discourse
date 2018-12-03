require_relative 'database_3_0'
require_relative 'database_3_1'
require_relative '../support/constants'

module ImportScripts::PhpBB3
  class Database_3_2 < Database_3_1
    # def fetch_posts(last_post_id)
    #   query(<<-SQL, :post_id)
    #     SELECT p.post_id, p.topic_id, t.forum_id, t.topic_title, t.topic_first_post_id, p.poster_id,
    #       p.post_text, p.post_time, t.topic_status, t.topic_type, t.poll_title, t.topic_views,
    #       CASE WHEN t.poll_length > 0 THEN t.poll_start + t.poll_length ELSE NULL END AS poll_end,
    #       t.poll_max_options, p.post_attachment, p.poster_ip,
    #       CASE WHEN u.user_type = #{Constants::USER_TYPE_IGNORE} THEN p.post_username ELSE NULL END post_username
    #     FROM #{@table_prefix}posts p
    #       JOIN #{@table_prefix}topics t ON (p.topic_id = t.topic_id)
    #       JOIN #{@table_prefix}users u ON (p.poster_id = u.user_id)
    #     WHERE p.post_id > #{last_post_id}
    #     ORDER BY p.post_id
    #     LIMIT #{@batch_size}
    #   SQL
    # end
  end

    def fetch_posts(last_post_id)
      query(<<-SQL, :post_id)
        SELECT p.post_id, p.topic_id, t.forum_id, t.topic_title, t.topic_first_post_id, p.poster_id,
          p.post_text, p.post_time, t.topic_status, t.topic_type, t.poll_title, t.topic_views,
          CASE WHEN t.poll_length > 0 THEN t.poll_start + t.poll_length ELSE NULL END AS poll_end,
          t.poll_max_options, p.post_attachment, p.poster_ip,
          CASE WHEN u.user_type = #{Constants::USER_TYPE_IGNORE} THEN p.post_username ELSE NULL END post_username
        FROM #{@table_prefix}posts p
          JOIN #{@table_prefix}topics t ON (p.topic_id = t.topic_id)
          JOIN #{@table_prefix}users u ON (p.poster_id = u.user_id)
        WHERE p.post_id > #{last_post_id}
        and p.post_id = 8929
        ORDER BY p.post_id
        LIMIT #{@batch_size}
      SQL
    end

end
