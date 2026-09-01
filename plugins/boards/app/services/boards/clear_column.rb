# frozen_string_literal: true

module Boards
  class ClearColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :column_id, :integer

      validates :board_id, presence: true
      validates :column_id, presence: true
    end

    model :board
    policy :can_write
    model :column
    step :clear

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_write(board:, guardian:)
      guardian.can_write_boards_board?(board)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.column_id)
    end

    def clear(board:, column:, guardian:)
      cards = clearable_cards(board, column, guardian)

      remove_column_tag_from_topics(cards, column, guardian)

      cards.delete_all
    end

    def clearable_cards(board, column, guardian)
      cards = Card.where(board_id: board.id, column_id: column.id)
      visible_topic_ids =
        Topic
          .listable_topics
          .secured(guardian)
          .where(id: cards.where(card_type: :topic).where.not(topic_id: nil).select(:topic_id))
          .where.not(id: Category.where.not(topic_id: nil).select(:topic_id))
          .select(:id)

      cards.where(card_type: :floater).or(
        cards.where(card_type: :topic, topic_id: visible_topic_ids),
      )
    end

    def remove_column_tag_from_topics(cards, column, guardian)
      return if column.tag_id.blank?

      tag = Tag.find_by(id: column.tag_id)
      return if tag.blank?

      topic_ids = cards.where(card_type: :topic).where.not(topic_id: nil).pluck(:topic_id)
      return if topic_ids.empty?

      Topic
        .where(id: topic_ids)
        .includes(:tags)
        .find_each do |topic|
          next unless guardian.can_edit?(topic)
          updated_tags = topic.tags.map(&:name) - [tag.name]
          DiscourseTagging.tag_topic_by_names(topic, guardian, updated_tags)
        end
    end
  end
end
