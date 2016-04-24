require_relative 'database_base'
require_relative '../support/constants'

module ImportScripts::PhpBB3
  class Database_3_0 < DatabaseBase
    def count_users
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}_users u
          JOIN #{@table_prefix}_groups g ON g.group_id = u.group_id
        WHERE u.user_type != #{Constants::USER_TYPE_IGNORE}
      SQL
    end

    def fetch_users(last_user_id)
      query(<<-SQL, :user_id)
        SELECT u.user_id, u.user_email, u.username, u.user_password, u.user_regdate, u.user_lastvisit, u.user_ip,
          u.user_type, u.user_inactive_reason, g.group_name, b.ban_start, b.ban_end, b.ban_reason,
          u.user_posts, u.user_website, u.user_from, u.user_birthday, u.user_avatar_type, u.user_avatar
        FROM #{@table_prefix}_users u
          JOIN #{@table_prefix}_groups g ON (g.group_id = u.group_id)
          LEFT OUTER JOIN #{@table_prefix}_banlist b ON (
            u.user_id = b.ban_userid AND b.ban_exclude = 0 AND
            (b.ban_end = 0 OR b.ban_end >= UNIX_TIMESTAMP())
          )
        WHERE u.user_id > #{last_user_id} AND u.user_type != #{Constants::USER_TYPE_IGNORE}
        ORDER BY u.user_id
        LIMIT #{@batch_size}
      SQL
    end

    def count_anonymous_users
      count(<<-SQL)
        SELECT COUNT(DISTINCT post_username) AS count
        FROM #{@table_prefix}_posts
        WHERE post_username <> ''
      SQL
    end

    def fetch_anonymous_users(last_username)
      last_username = escape(last_username)

      query(<<-SQL, :post_username)
        SELECT post_username, MIN(post_time) AS first_post_time
        FROM #{@table_prefix}_posts
        WHERE post_username > '#{last_username}'
        GROUP BY post_username
        ORDER BY post_username
        LIMIT #{@batch_size}
      SQL
    end

    def fetch_categories
      query(<<-SQL)
        SELECT f.forum_id, f.parent_id, f.forum_name, f.forum_desc, x.first_post_time
        FROM #{@table_prefix}_forums f
          LEFT OUTER JOIN (
            SELECT MIN(topic_time) AS first_post_time, forum_id
            FROM #{@table_prefix}_topics
            GROUP BY forum_id
          ) x ON (f.forum_id = x.forum_id)
        WHERE f.forum_type != #{Constants::FORUM_TYPE_LINK}
        ORDER BY f.parent_id, f.left_id
      SQL
    end

    def count_posts
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}_posts
      SQL
    end

    def fetch_posts(last_post_id)
      query(<<-SQL, :post_id)
        SELECT p.post_id, p.topic_id, t.forum_id, t.topic_title, t.topic_first_post_id, p.poster_id,
          p.post_text, p.post_time, p.post_username, t.topic_status, t.topic_type, t.poll_title,
          CASE WHEN t.poll_length > 0 THEN t.poll_start + t.poll_length ELSE NULL END AS poll_end,
          t.poll_max_options, p.post_attachment
        FROM #{@table_prefix}_posts p
          JOIN #{@table_prefix}_topics t ON (p.topic_id = t.topic_id)
        WHERE p.post_id > #{last_post_id}
        ORDER BY p.post_id
        LIMIT #{@batch_size}
      SQL
    end

    def get_first_post_id(topic_id)
      query(<<-SQL).try(:first).try(:[], :topic_first_post_id)
        SELECT topic_first_post_id
        FROM #{@table_prefix}_topics
        WHERE topic_id = #{topic_id}
      SQL
    end

    def fetch_poll_options(topic_id)
      query(<<-SQL)
        SELECT o.poll_option_id, o.poll_option_text, o.poll_option_total AS total_votes,
          o.poll_option_total - (
            SELECT COUNT(DISTINCT v.vote_user_id)
              FROM #{@table_prefix}_poll_votes v
                JOIN #{@table_prefix}_users u ON (v.vote_user_id = u.user_id)
                JOIN #{@table_prefix}_topics t ON (v.topic_id = t.topic_id)
              WHERE v.poll_option_id = o.poll_option_id AND v.topic_id = o.topic_id
          ) AS anonymous_votes
        FROM #{@table_prefix}_poll_options o
        WHERE o.topic_id = #{topic_id}
        ORDER BY o.poll_option_id
      SQL
    end

    def fetch_poll_votes(topic_id)
      # this query ignores invalid votes that belong to non-existent users or topics
      query(<<-SQL)
        SELECT u.user_id, v.poll_option_id
        FROM #{@table_prefix}_poll_votes v
          JOIN #{@table_prefix}_poll_options o ON (v.poll_option_id = o.poll_option_id AND v.topic_id = o.topic_id)
          JOIN #{@table_prefix}_users u ON (v.vote_user_id = u.user_id)
          JOIN #{@table_prefix}_topics t ON (v.topic_id = t.topic_id)
        WHERE v.topic_id = #{topic_id}
      SQL
    end

    def get_voters(topic_id)
      # anonymous voters can't be counted, but lets try to make the count look "correct" anyway
      query(<<-SQL).first
        SELECT MAX(x.total_voters) AS total_voters,
          MAX(x.total_voters) - (
            SELECT COUNT(DISTINCT v.vote_user_id)
            FROM #{@table_prefix}_poll_votes v
              JOIN #{@table_prefix}_poll_options o ON (v.poll_option_id = o.poll_option_id AND v.topic_id = o.topic_id)
              JOIN #{@table_prefix}_users u ON (v.vote_user_id = u.user_id)
              JOIN #{@table_prefix}_topics t ON (v.topic_id = t.topic_id)
            WHERE v.topic_id = #{topic_id}
          ) AS anonymous_voters
        FROM (
          SELECT COUNT(DISTINCT vote_user_id) AS total_voters
          FROM #{@table_prefix}_poll_votes
          WHERE topic_id  = #{topic_id}
          UNION
          SELECT MAX(poll_option_total) AS total_voters
          FROM #{@table_prefix}_poll_options
          WHERE topic_id = #{topic_id}
        ) x
      SQL
    end

    def get_max_attachment_size
      query(<<-SQL).first[:filesize]
        SELECT IFNULL(MAX(filesize), 0) AS filesize
        FROM #{@table_prefix}_attachments
      SQL
    end

    def fetch_attachments(topic_id, post_id)
      query(<<-SQL)
        SELECT physical_filename, real_filename
        FROM #{@table_prefix}_attachments
        WHERE topic_id = #{topic_id} AND post_msg_id = #{post_id}
        ORDER BY filetime DESC, post_msg_id
      SQL
    end

    def count_messages
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}_privmsgs m
        WHERE NOT EXISTS ( -- ignore duplicate messages
            SELECT 1
            FROM #{@table_prefix}_privmsgs x
            WHERE x.msg_id < m.msg_id AND x.root_level = m.root_level AND x.author_id = m.author_id
              AND x.to_address = m.to_address AND x.message_time = m.message_time
          )
      SQL
    end

    def fetch_messages(last_msg_id)
      query(<<-SQL, :msg_id)
        SELECT m.msg_id, m.root_level AS root_msg_id, m.author_id, m.message_time, m.message_subject,
          m.message_text, m.to_address, r.author_id AS root_author_id, r.to_address AS root_to_address, (
            SELECT COUNT(*)
            FROM #{@table_prefix}_attachments a
            WHERE a.topic_id = 0 AND m.msg_id = a.post_msg_id
          ) AS attachment_count
        FROM #{@table_prefix}_privmsgs m
          LEFT OUTER JOIN #{@table_prefix}_privmsgs r ON (m.root_level = r.msg_id)
        WHERE m.msg_id > #{last_msg_id}
          AND NOT EXISTS ( -- ignore duplicate messages
            SELECT 1
            FROM #{@table_prefix}_privmsgs x
            WHERE x.msg_id < m.msg_id AND x.root_level = m.root_level AND x.author_id = m.author_id
              AND x.to_address = m.to_address AND x.message_time = m.message_time
          )
        ORDER BY m.msg_id
        LIMIT #{@batch_size}
      SQL
    end

    def count_bookmarks
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}_bookmarks
      SQL
    end

    def fetch_bookmarks(last_user_id, last_topic_id)
      query(<<-SQL, :user_id, :topic_first_post_id)
        SELECT b.user_id, t.topic_first_post_id
        FROM #{@table_prefix}_bookmarks b
          JOIN #{@table_prefix}_topics t ON (b.topic_id = t.topic_id)
        WHERE b.user_id > #{last_user_id} AND b.topic_id > #{last_topic_id}
        ORDER BY b.user_id, b.topic_id
        LIMIT #{@batch_size}
      SQL
    end

    def get_config_values
      query(<<-SQL).first
        SELECT
          (SELECT config_value FROM #{@table_prefix}_config WHERE config_name = 'version') AS phpbb_version,
          (SELECT config_value FROM #{@table_prefix}_config WHERE config_name = 'avatar_gallery_path') AS avatar_gallery_path,
          (SELECT config_value FROM #{@table_prefix}_config WHERE config_name = 'avatar_path') AS avatar_path,
          (SELECT config_value FROM #{@table_prefix}_config WHERE config_name = 'avatar_salt') AS avatar_salt,
          (SELECT config_value FROM #{@table_prefix}_config WHERE config_name = 'smilies_path') AS smilies_path,
          (SELECT config_value FROM #{@table_prefix}_config WHERE config_name = 'upload_path') AS attachment_path
      SQL
    end
  end
end
