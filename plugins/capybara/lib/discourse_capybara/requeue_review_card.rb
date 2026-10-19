# frozen_string_literal: true

module ::DiscourseCapybara
  class RequeueReviewCard
    def self.call(post, options = {})
      return if Rails.env.production? || !SiteSetting.capybara_enabled || options[:import_mode]
      return if post.deleted_at || post.post_type != Post.types[:regular] || post.post_number <= 1
      return if post.user_id.to_i <= 0 || post.user&.username == "codex-bot"
      return if post.topic.blank? || post.topic.deleted_at

      board = Boards::Board.find_by(id: CodexBoardBot::BOARD_ID)
      return if board.blank? || board.archived?
      target = board.columns.find_by(title: "TODO")
      bot = User.find_by_username("codex-bot")
      return if target.blank? || bot.blank?

      guardian = bot.guardian
      board
        .cards
        .where(card_type: :topic, topic_id: post.topic_id)
        .find_each do |card|
          original_column_id = nil
          moved = false
          card.with_lock do
            next unless card.column.title == "REVIEW"
            original_column_id = card.column_id
            raw = { "column_id" => target.id }
            result =
              Boards::UpdateCard.call(
                guardian: guardian,
                params: raw.merge("board_id" => board.id, "id" => card.id),
                options: {
                  raw_card_params: raw,
                },
              )
            raise Discourse::InvalidParameters unless result.success?
            card.reload
            moved = true
          end
          next unless moved

          payload = Boards::CardSerializer.new(card, root: false, scope: guardian).as_json
          Boards::Publisher.publish_card_moved!(
            board,
            payload,
            original_column_id,
            acting_user: bot,
            client_id: nil,
          )
          Boards::Publisher.publish_topic_memberships_changed!(
            card.topic,
            client_id: nil,
            refresh_stream: false,
          )
        end
    end
  end
end
