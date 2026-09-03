# frozen_string_literal: true

module Boards
  class DestroyCard
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :id, :integer

      validates :board_id, presence: true
      validates :id, presence: true
    end

    model :board
    policy :can_write
    model :card
    policy :can_see_card_topic
    policy :card_is_deletable
    step :destroy

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_write(board:, guardian:)
      guardian.can_write_boards_board?(board)
    end

    def fetch_card(board:, params:)
      board.cards.find_by(id: params.id)
    end

    def can_see_card_topic(card:, guardian:)
      !card.topic? || card.topic.blank? || guardian.can_see?(card.topic)
    end

    def card_is_deletable(card:)
      true
    end

    def destroy(card:, guardian:)
      remove_column_tag(card, guardian) if card.topic?
      card.destroy!
    end

    def remove_column_tag(card, guardian)
      column = card.column
      return if column&.tag_id.blank?
      topic = card.topic
      return if topic.blank? || !guardian.can_edit?(topic)

      tag = Tag.find_by(id: column.tag_id)
      return if tag.blank?

      updated_tags = topic.tags.map(&:name) - [tag.name]
      DiscourseTagging.tag_topic_by_names(topic, guardian, updated_tags)
    end
  end
end
