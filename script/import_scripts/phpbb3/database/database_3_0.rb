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

    def fetch_users(offset)
      query(<<-SQL)
        SELECT u.user_id, u.user_email, u.username, u.user_password, u.user_regdate, u.user_lastvisit, u.user_ip,
          u.user_type, u.user_inactive_reason, g.group_name, b.ban_start, b.ban_end, b.ban_reason,
          u.user_posts, u.user_website, u.user_from, u.user_birthday, u.user_avatar_type, u.user_avatar
        FROM #{@table_prefix}_users u
          JOIN #{@table_prefix}_groups g ON (g.group_id = u.group_id)
          LEFT OUTER JOIN #{@table_prefix}_banlist b ON (
            u.user_id = b.ban_userid AND b.ban_exclude = 0 AND
            (b.ban_end = 0 OR b.ban_end >= UNIX_TIMESTAMP())
          )
        WHERE u.user_type != #{Constants::USER_TYPE_IGNORE}
        ORDER BY u.user_id ASC
        LIMIT #{@batch_size}
        OFFSET #{offset}
      SQL
    end

    def count_anonymous_users
      count(<<-SQL)
        SELECT COUNT(DISTINCT post_username) AS count
        FROM #{@table_prefix}_posts
        WHERE post_username <> ''
      SQL
    end

    def fetch_anonymous_users(offset)
      query(<<-SQL)
        SELECT post_username, MIN(post_time) AS first_post_time
        FROM #{@table_prefix}_posts
        WHERE post_username <> ''
        GROUP BY post_username
        ORDER BY post_username ASC
        LIMIT #{@batch_size}
        OFFSET #{offset}
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
        ORDER BY f.parent_id ASC, f.left_id ASC
      SQL
    end

    def count_posts
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}_posts
      SQL
    end

    def fetch_posts(offset)
      query(<<-SQL)
        SELECT p.post_id, p.topic_id, t.forum_id, t.topic_title, t.topic_first_post_id, p.poster_id,
          p.post_text, p.post_time, p.post_username, t.topic_status, t.topic_type, t.poll_title,
          CASE WHEN t.poll_length > 0 THEN t.poll_start + t.poll_length ELSE NULL END AS poll_end,
          t.poll_max_options, p.post_attachment
        FROM #{@table_prefix}_posts p
          JOIN #{@table_prefix}_topics t ON (p.topic_id = t.topic_id)
        ORDER BY p.post_id ASC
        LIMIT #{@batch_size}
        OFFSET #{offset}
      SQL
    end

    def get_first_post_id(topic_id)
      query(<<-SQL).first[:topic_first_post_id]
        SELECT topic_first_post_id
        FROM #{@table_prefix}_topics
        WHERE topic_id = #{topic_id}
      SQL
    end

    def fetch_poll_options(topic_id)
      query(<<-SQL)
        SELECT poll_option_id, poll_option_text, poll_option_total
        FROM #{@table_prefix}_poll_options
        WHERE topic_id = #{topic_id}
        ORDER BY poll_option_id
      SQL
    end

    def fetch_poll_votes(topic_id)
      # this query ignores votes from users that do not exist anymore
      query(<<-SQL)
        SELECT u.user_id, v.poll_option_id
        FROM #{@table_prefix}_poll_votes v
          JOIN #{@table_prefix}_users u ON (v.vote_user_id = u.user_id)
        WHERE v.topic_id = #{topic_id}
      SQL
    end

    def count_voters(topic_id)
      # anonymous voters can't be counted, but lets try to make the count look "correct" anyway
      count(<<-SQL)
        SELECT MAX(count) AS count
        FROM (
          SELECT COUNT(DISTINCT vote_user_id) AS count
          FROM #{@table_prefix}_poll_votes
          WHERE topic_id  = #{topic_id}
          UNION
          SELECT MAX(poll_option_total) AS count
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
        ORDER BY filetime DESC, post_msg_id ASC
      SQL
    end

    def count_messages(use_fixed_messages)
      if use_fixed_messages
        count(<<-SQL)
          SELECT COUNT(*) AS count
          FROM #{@table_prefix}_import_privmsgs
        SQL
      else
        count(<<-SQL)
          SELECT COUNT(*) AS count
          FROM #{@table_prefix}_privmsgs
        SQL
      end
    end

    def fetch_messages(use_fixed_messages, offset)
      if use_fixed_messages
        query(<<-SQL)
          SELECT m.msg_id, i.root_msg_id, m.author_id, m.message_time, m.message_subject, m.message_text,
            IFNULL(a.attachment_count, 0) AS attachment_count
          FROM #{@table_prefix}_privmsgs m
            JOIN #{@table_prefix}_import_privmsgs i ON (m.msg_id = i.msg_id)
            LEFT OUTER JOIN (
              SELECT post_msg_id, COUNT(*) AS attachment_count
              FROM #{@table_prefix}_attachments
              WHERE topic_id = 0
              GROUP BY post_msg_id
            ) a ON (m.msg_id = a.post_msg_id)
          ORDER BY i.root_msg_id ASC, m.msg_id ASC
          LIMIT #{@batch_size}
          OFFSET #{offset}
        SQL
      else
        query(<<-SQL)
          SELECT m.msg_id, m.root_level AS root_msg_id, m.author_id, m.message_time, m.message_subject,
            m.message_text, IFNULL(a.attachment_count, 0) AS attachment_count
          FROM #{@table_prefix}_privmsgs m
            LEFT OUTER JOIN (
              SELECT post_msg_id, COUNT(*) AS attachment_count
              FROM #{@table_prefix}_attachments
              WHERE topic_id = 0
              GROUP BY post_msg_id
            ) a ON (m.msg_id = a.post_msg_id)
          ORDER BY m.root_level ASC, m.msg_id ASC
          LIMIT #{@batch_size}
          OFFSET #{offset}
        SQL
      end
    end

    def fetch_message_participants(msg_id, use_fixed_messages)
      if use_fixed_messages
        query(<<-SQL)
          SELECT m.to_address
          FROM #{@table_prefix}_privmsgs m
            JOIN #{@table_prefix}_import_privmsgs i ON (m.msg_id = i.msg_id)
          WHERE i.msg_id = #{msg_id} OR i.root_msg_id = #{msg_id}
        SQL
      else
        query(<<-SQL)
          SELECT m.to_address
          FROM #{@table_prefix}_privmsgs m
          WHERE m.msg_id = #{msg_id} OR m.root_level = #{msg_id}
        SQL
      end
    end

    def calculate_fixed_messages
      drop_temp_import_message_table
      create_temp_import_message_table
      fill_temp_import_message_table

      drop_import_message_table
      create_import_message_table
      fill_import_message_table

      drop_temp_import_message_table
    end

    def count_bookmarks
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}_bookmarks
      SQL
    end

    def fetch_bookmarks(offset)
      query(<<-SQL)
        SELECT b.user_id, t.topic_first_post_id
        FROM #{@table_prefix}_bookmarks b
          JOIN #{@table_prefix}_topics t ON (b.topic_id = t.topic_id)
        ORDER BY b.user_id ASC, b.topic_id ASC
        LIMIT #{@batch_size}
        OFFSET #{offset}
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

    protected

    def drop_temp_import_message_table
      query("DROP TABLE IF EXISTS #{@table_prefix}_import_privmsgs_temp")
    end

    def create_temp_import_message_table
      query(<<-SQL)
        CREATE TABLE #{@table_prefix}_import_privmsgs_temp (
          msg_id MEDIUMINT(8) NOT NULL,
          root_msg_id MEDIUMINT(8) NOT NULL,
          recipient_id MEDIUMINT(8),
          normalized_subject VARCHAR(255) NOT NULL,
          PRIMARY KEY (msg_id)
        )
      SQL
    end

    # this removes duplicate messages, converts the to_address to a number
    # and stores the message_subject in lowercase and without the prefix "Re: "
    def fill_temp_import_message_table
      query(<<-SQL)
        INSERT INTO #{@table_prefix}_import_privmsgs_temp (msg_id, root_msg_id, recipient_id, normalized_subject)
        SELECT m.msg_id, m.root_level,
          CASE WHEN m.root_level = 0 AND INSTR(m.to_address, ':') = 0 THEN
            CAST(SUBSTRING(m.to_address, 3) AS SIGNED INTEGER)
          ELSE NULL END AS recipient_id,
          LOWER(CASE WHEN m.message_subject LIKE 'Re: %' THEN
            SUBSTRING(m.message_subject, 5)
          ELSE m.message_subject END) AS normalized_subject
        FROM #{@table_prefix}_privmsgs m
        WHERE NOT EXISTS (
            SELECT 1
            FROM #{@table_prefix}_privmsgs x
            WHERE x.msg_id < m.msg_id AND x.root_level = m.root_level AND x.author_id = m.author_id
              AND x.to_address = m.to_address AND x.message_time = m.message_time
          )
      SQL
    end

    def drop_import_message_table
      query("DROP TABLE IF EXISTS #{@table_prefix}_import_privmsgs")
    end

    def create_import_message_table
      query(<<-SQL)
        CREATE TABLE #{@table_prefix}_import_privmsgs (
          msg_id MEDIUMINT(8) NOT NULL,
          root_msg_id MEDIUMINT(8) NOT NULL,
          PRIMARY KEY (msg_id),
          INDEX #{@table_prefix}_import_privmsgs_root_msg_id (root_msg_id)
        )
      SQL
    end

    # this tries to calculate the actual root_level (= msg_id of the first message in a
    # private conversation) based on subject, time, author and recipient
    def fill_import_message_table
      query(<<-SQL)
        INSERT INTO #{@table_prefix}_import_privmsgs (msg_id, root_msg_id)
        SELECT m.msg_id, CASE WHEN i.root_msg_id = 0 THEN
          COALESCE((
            SELECT a.msg_id
            FROM #{@table_prefix}_privmsgs a
              JOIN #{@table_prefix}_import_privmsgs_temp b ON (a.msg_id = b.msg_id)
            WHERE ((a.author_id = m.author_id AND b.recipient_id = i.recipient_id) OR
                   (a.author_id = i.recipient_id AND b.recipient_id = m.author_id))
              AND b.normalized_subject = i.normalized_subject
              AND a.msg_id <> m.msg_id
              AND a.message_time < m.message_time
            ORDER BY a.message_time ASC
            LIMIT 1
          ), 0) ELSE i.root_msg_id END AS root_msg_id
        FROM #{@table_prefix}_privmsgs m
          JOIN #{@table_prefix}_import_privmsgs_temp i ON (m.msg_id = i.msg_id)
      SQL
    end
  end
end
