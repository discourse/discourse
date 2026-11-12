# frozen_string_literal: true

module Boards
  module Action
    class BuildTopicBoardMembershipsMap < Service::ActionBase
      option :topics
      option :guardian

      # Returns a hash in the format:
      #
      # {
      #   topic_id => {
      #     board_id => [cards]
      #   }
      # }
      #
      # With the board & column details preloaded for
      # each card.
      def call
        cards = cards_query(readable_board_ids).to_a

        cards
          .group_by(&:topic_id)
          .transform_values do |topic_cards|
            topic_cards
              .group_by(&:board_id)
              .sort_by do |_, board_cards|
                [board_cards.first.board.name.downcase, board_cards.first.board_id]
              end
              .to_h
          end
      end

      private

      def cards_query(readable_board_ids)
        Boards::Card
          .topic
          .with_column
          .where(topic_id: Array(topics).map(&:id), board_id: readable_board_ids)
          .includes(:column, :board)
      end

      def readable_board_ids
        member_boards = Boards::Board.with_any_acl_permissions(guardian, %w[view edit manage])
        anonymous_boards = Boards::Board.with_any_acl_permissions(Guardian.new, %w[view])

        member_boards.or(anonymous_boards).pluck(:id).to_set
      end
    end
  end
end
