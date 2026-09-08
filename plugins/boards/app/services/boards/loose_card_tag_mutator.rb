# frozen_string_literal: true

module Boards
  module LooseCardTagMutator
    class << self
      def apply_to_card!(card:, column:, remove_tag_ids: [])
        return unless card.floater?

        tag_ids =
          ColumnTagResolver.normalize_tag_ids(card.tag_ids) -
            ColumnTagResolver.normalize_tag_ids(remove_tag_ids)
        card.tag_ids = ColumnTagResolver.resolve_tag_ids(current_tag_ids: tag_ids, column:)
      end

      def apply_to_column!(column:, remove_tag_ids: [])
        column
          .cards
          .where(card_type: Card.card_types[:floater])
          .find_each do |card|
            apply_to_card!(card:, column:, remove_tag_ids:)
            card.save! if card.changed?
          end
      end
    end
  end
end
