# frozen_string_literal: true

module Boards
  class InlineOneboxHandler
    def self.handle(url, route, opts = {})
      opts ||= {}

      if route[:card_id].present?
        build_card_onebox(url, route[:card_id], route[:id], opts)
      else
        build_board_onebox(url, route[:id])
      end
    end

    private

    def self.build_card_onebox(url, card_id, board_id, opts)
      board = Boards::Board.find_by(id: board_id)
      return if !board || !board.can_be_oneboxed?

      card = Boards::Card.includes(:topic).find_by(id: card_id, board_id: board_id)
      return if !card
      if card.topic?
        if card.topic.blank? ||
             Oneboxer.local_topic(card.topic.url, { id: card.topic_id }, opts).blank?
          return
        end
      end

      title =
        I18n.t(
          "boards.onebox.inline_to_card",
          card_name: card.unicode_resolved_title,
          board_name: board.unicode_name,
        )

      { url: url, title: title }
    end

    def self.build_board_onebox(url, board_id)
      board = Boards::Board.find_by(id: board_id)
      return if !board || !board.can_be_oneboxed?

      title = I18n.t("boards.onebox.inline_to_board", board_name: board.unicode_name)

      { url: url, title: title }
    end
  end
end
