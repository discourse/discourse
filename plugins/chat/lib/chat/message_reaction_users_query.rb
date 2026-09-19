# frozen_string_literal: true

module Chat
  # Returns a paginated list of the users who reacted to a chat message, one row
  # per reaction (a user who reacted with several emojis appears once per emoji).
  # Used by the reactions users popup to lazily page through reactors.
  class MessageReactionUsersQuery
    def self.call(message:, emoji: nil, limit: 30, offset: 0, current_user_id: nil)
      query =
        new(
          message: message,
          emoji: emoji,
          limit: limit,
          offset: offset,
          current_user_id: current_user_id,
        )
      [query.rows, query.total]
    end

    def initialize(message:, emoji: nil, limit: 30, offset: 0, current_user_id: nil)
      @message = message
      @emoji = emoji
      @limit = limit
      @offset = offset
      @current_user_id = current_user_id
    end

    def rows
      @rows ||= DB.query(<<~SQL, **bindings)
          SELECT u.id, u.username, u.name, u.uploaded_avatar_id, cmr.emoji AS reaction
          FROM chat_message_reactions cmr
          INNER JOIN users u ON u.id = cmr.user_id
          WHERE cmr.chat_message_id = :message_id
          #{emoji_filter_sql}
          #{ignored_users_filter_sql}
          ORDER BY cmr.created_at ASC, cmr.id ASC
          LIMIT :limit OFFSET :offset
        SQL
    end

    def total
      @total ||= DB.query_single(<<~SQL, **bindings).first
        SELECT COUNT(*)
        FROM chat_message_reactions cmr
        WHERE cmr.chat_message_id = :message_id
        #{emoji_filter_sql}
        #{ignored_users_filter_sql("cmr.user_id")}
      SQL
    end

    private

    attr_reader :message, :emoji, :limit, :offset, :current_user_id

    def bindings
      {
        message_id: message.id,
        emoji: emoji,
        limit: limit,
        offset: offset,
        current_user_id: current_user_id,
      }
    end

    def emoji_filter_sql
      return "" if emoji.blank?
      "AND cmr.emoji = :emoji"
    end

    def ignored_users_filter_sql(user_column = "u.id")
      return "" if current_user_id.blank?

      <<~SQL
        AND NOT EXISTS (
          SELECT 1 FROM ignored_users ig
          WHERE ig.user_id = :current_user_id
            AND ig.ignored_user_id = #{user_column}
            AND ig.ignored_user_id <> :current_user_id
        )
      SQL
    end
  end
end
