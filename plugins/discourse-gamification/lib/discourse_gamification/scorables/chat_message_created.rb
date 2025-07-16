# frozen_string_literal: true
module ::DiscourseGamification
  class ChatMessageCreated < Scorable
    def self.enabled?
      SiteSetting.chat_enabled && score_multiplier > 0
    end

    def self.score_multiplier
      SiteSetting.chat_message_created_score_value
    end

    def self.query
      <<~SQL
        SELECT
          m.user_id,
          date_trunc('day', m.created_at) AS date,
          COUNT(*) * #{score_multiplier} AS points
        FROM
          chat_messages AS m
        JOIN
          chat_channels AS c ON c.id = m.chat_channel_id
        LEFT JOIN (
          SELECT direct_message_channel_id
          FROM direct_message_users
          GROUP BY direct_message_channel_id
          HAVING COUNT(DISTINCT user_id) > 1
        ) AS dm ON dm.direct_message_channel_id = c.chatable_id
        WHERE
          m.created_at >= :since AND
          m.deleted_at IS NULL AND
          (c.chatable_type <> 'DirectMessage' OR dm.direct_message_channel_id IS NOT NULL)
        GROUP BY
          m.user_id, date_trunc('day', m.created_at)
      SQL
    end
  end
end
