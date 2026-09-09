# frozen_string_literal: true

module Boards
  class CheckBoardTopicConstraintMismatches
    include Service::Base

    params do
      attribute :id, :integer
      attribute :topic_id, :integer
      attribute :target_column_id, :integer

      validates :id, presence: true
      validates :topic_id, presence: true
      validates :target_column_id, presence: true
    end

    model :board
    policy :can_edit_board
    model :topic
    policy :can_view_topic
    model :target_column
    model :categories_needed, optional: true
    model :tags_needed, optional: true

    private

    def fetch_board(params:)
      Board.find_by(id: params.id)
    end

    def can_edit_board(board:, guardian:)
      guardian.can_write_boards_board?(board)
    end

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def can_view_topic(topic:, guardian:)
      guardian.can_see?(topic)
    end

    def fetch_target_column(params:, board:)
      board.columns.find_by(id: params.target_column_id)
    end

    # If the column's category (or the topic's current category) is outside the board's
    # categories, return the board categories so the user can choose a replacement.
    def fetch_categories_needed(topic:, target_column:, board:)
      return [] if board.category_ids.empty?

      effective_category_id = target_column.move_to_category_id || topic.category_id
      return [] if board.category_ids.include?(effective_category_id)

      board.category_ids
    end

    # If none of the effective tags belong to the board, return its tags so the user can
    # choose a replacement.
    def fetch_tags_needed(topic:, target_column:, board:, guardian:)
      return [] if board.tag_ids.empty?

      effective_tag_ids = topic.tag_ids.dup

      # A topic should only have the tag for its new column. Remove tags from the other
      # columns, including every column tag when the target column is untagged.
      sibling_tag_ids =
        board.columns.filter_map { |column| column.tag_id if column.id != target_column.id }
      effective_tag_ids -= sibling_tag_ids

      if target_column.tag_id.present? && effective_tag_ids.exclude?(target_column.tag_id)
        effective_tag_ids << target_column.tag_id
      end

      return [] if (board.tag_ids & effective_tag_ids).any?

      Tag.visible(guardian).where(id: board.tag_ids).order(:name).pluck(:name)
    end
  end
end
