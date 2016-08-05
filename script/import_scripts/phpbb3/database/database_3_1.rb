require_relative 'database_3_0'
require_relative '../support/constants'

module ImportScripts::PhpBB3
  class Database_3_1 < Database_3_0
    def fetch_users(last_user_id)
      query(<<-SQL, :user_id)
        SELECT u.user_id, u.user_email, u.username,
          CASE WHEN u.user_password LIKE '$2y$%'
            THEN CONCAT('$2a$', SUBSTRING(u.user_password, 5))
            ELSE u.user_password
          END AS user_password, u.user_regdate, u.user_lastvisit, u.user_ip,
          u.user_type, u.user_inactive_reason, g.group_name, b.ban_start, b.ban_end, b.ban_reason,
          u.user_posts, f.pf_phpbb_website AS user_website, f.pf_phpbb_location AS user_from,
          u.user_birthday, u.user_avatar_type, u.user_avatar
        FROM #{@table_prefix}users u
          LEFT OUTER JOIN #{@table_prefix}profile_fields_data f ON (u.user_id = f.user_id)
          JOIN #{@table_prefix}groups g ON (g.group_id = u.group_id)
          LEFT OUTER JOIN #{@table_prefix}banlist b ON (
            u.user_id = b.ban_userid AND b.ban_exclude = 0 AND
            (b.ban_end = 0 OR b.ban_end >= UNIX_TIMESTAMP())
          )
        WHERE u.user_id > #{last_user_id} AND u.user_type != #{Constants::USER_TYPE_IGNORE}
        ORDER BY u.user_id
        LIMIT #{@batch_size}
      SQL
    end
  end
end
