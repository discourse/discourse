# frozen_string_literal: true
module DiscourseGamification
  class ChatReactionGiven < Scorable
    def self.enabled?(leaderboard: nil)
      SiteSetting.chat_enabled && super
    end

    def self.query(leaderboard: nil)
      <<~SQL
        SELECT
          reactions.user_id AS user_id,
          date_trunc('day', reactions.created_at) AS date,
          COUNT(*) * #{score_multiplier(leaderboard:)} AS points
        FROM
          chat_message_reactions AS reactions
        INNER JOIN chat_messages AS cm
          ON cm.id = reactions.chat_message_id
        INNER JOIN chat_channels AS cc
          ON cc.id = cm.chat_channel_id
        WHERE
          cc.deleted_at IS NULL AND
          cm.deleted_at IS NULL AND
          cm.user_id <> reactions.user_id AND
          reactions.created_at >= :since
        GROUP BY
          1, 2
      SQL
    end
  end
end
