# frozen_string_literal: true

module Boards
  class CardOrdering
    GAP_SIZE = 65_536

    class << self
      def place_card!(card, column:, after_card_id: nil, position_first: false)
        if same_column_recency_reorder?(card, column, after_card_id, position_first)
          raise_recency_reorder_error!
        end

        if column.recency? && !card.new_record? && card.column_id == column.id
          card.save!
          return card
        end

        card.transaction do
          scope = card.board.cards.with_column.where(column_id: column.id).where.not(id: card.id)

          position =
            if column.recency?
              insert_at_beginning(scope)
            else
              compute_position(scope, after_card_id:, position_first:)
            end

          if position.nil?
            rebalance_column!(card.board, column)
            position = compute_position(scope, after_card_id:, position_first:)
          end

          stamp_column_changed_at!(card, column)
          card.column_id = column.id
          card.position = position
          card.save!
        end
      end

      def append_to_column!(card, column)
        scope = card.board.cards.with_column.where(column_id: column.id)
        next_position =
          if column.recency?
            insert_at_beginning(scope)
          else
            scope.maximum(:position).to_i + GAP_SIZE
          end

        stamp_column_changed_at!(card, column)
        card.column_id = column.id
        card.position = next_position
        card
      end

      private

      def compute_position(scope, after_card_id:, position_first:)
        if after_card_id.present?
          insert_after_card(scope, after_card_id)
        elsif position_first
          insert_at_beginning(scope)
        else
          insert_at_end(scope)
        end
      end

      def same_column_recency_reorder?(card, column, after_card_id, position_first)
        column.recency? && !card.new_record? && card.column_id == column.id &&
          (after_card_id.present? || position_first)
      end

      def raise_recency_reorder_error!
        raise Discourse::InvalidParameters.new(
                I18n.t("boards.errors.cannot_reorder_recency_column"),
              )
      end

      def stamp_column_changed_at!(card, column)
        unless card.new_record? || card.column_id != column.id || card.column_changed_at.blank?
          return
        end

        card.column_changed_at = Time.current
      end

      def insert_after_card(scope, after_card_id)
        anchor = scope.find_by(id: after_card_id)
        return insert_at_end(scope) if anchor.nil?

        neighbor =
          scope
            .where(
              "position > :pos OR (position = :pos AND id > :id)",
              pos: anchor.position,
              id: anchor.id,
            )
            .order(:position, :id)
            .pick(:position)

        if neighbor.nil?
          anchor.position + GAP_SIZE
        else
          gap = neighbor - anchor.position
          return nil if gap <= 1
          anchor.position + gap / 2
        end
      end

      def insert_at_beginning(scope)
        first_pos = scope.order(:position, :id).pick(:position)
        return 0 if first_pos.nil?
        first_pos - GAP_SIZE
      end

      def insert_at_end(scope)
        max_pos = scope.maximum(:position)
        return 0 if max_pos.nil?
        max_pos + GAP_SIZE
      end

      def rebalance_column!(board, column)
        card_ids =
          board.cards.with_column.where(column_id: column.id).order(:position, :id).pluck(:id)

        return if card_ids.empty?

        whens = card_ids.map.with_index { |id, i| "WHEN #{id} THEN #{i * GAP_SIZE}" }.join(" ")

        Card.where(id: card_ids).update_all("position = CASE id #{whens} END")
      end
    end
  end
end
