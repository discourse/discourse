# frozen_string_literal: true
module ::DiscourseGamification
  class ChatReactionReceived < Scorable
    def self.enabled?
      SiteSetting.chat_enabled && score_multiplier > 0
    end

    def self.score_multiplier
      SiteSetting.chat_reaction_received_score_value
    end

    def self.query
      <<~SQL
        SELECT
          cm.user_id AS user_id,
          date_trunc('day', reactions.created_at) AS date,
          COUNT(*) * #{score_multiplier} AS points
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
