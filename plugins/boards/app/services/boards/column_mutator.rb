# frozen_string_literal: true

module Boards
  class ColumnMutator
    class << self
      def apply!(column:, attributes:, guardian:, position: column.position)
        payload = attributes.with_indifferent_access
        previous_tag_id = column.tag_id
        resolved_tag_id = resolve_tag_id(payload, guardian)
        ensure_tag_is_unique!(column:, tag_id: resolved_tag_id, tag_name: payload[:tag_name])

        column.assign_attributes(
          title: payload[:title],
          icon: payload[:icon],
          tag_id: resolved_tag_id,
          default_sort: normalize_default_sort(payload[:default_sort]),
          move_to_category_id: payload[:move_to_category_id],
          move_to_assigned: payload[:move_to_assigned],
          move_to_status: payload[:move_to_status],
          color: payload[:color],
          position:,
        )
        column.save!

        if previous_tag_id != column.tag_id
          enforce_loose_card_tags!(column.board, [[column.id, previous_tag_id]])
        end

        column
      end

      def destroy!(column:)
        board = column.board
        board.cards.where(column_id: column.id).delete_all
        column.destroy!
        compact_positions!(board)
      end

      def enforce_loose_card_tags!(board, column_tag_changes)
        return if column_tag_changes.empty?

        board.columns.reset
        previous_tag_ids_by_column_id = column_tag_changes.to_h
        board.columns.find_each do |column|
          LooseCardTagMutator.apply_to_column!(
            column:,
            remove_tag_ids: [previous_tag_ids_by_column_id[column.id]],
          )
        end
      end

      def normalize_default_sort(value)
        sort = value.presence || "priority"
        sort = sort.to_s
        return sort if Column.default_sorts.key?(sort)

        raise Discourse::InvalidParameters.new(
                I18n.t("boards.errors.invalid_column_sort", sort: sort),
              )
      end

      private

      def resolve_tag_id(payload, guardian)
        tag_name = payload[:tag_name].presence
        tag_name ? VisibleTagResolver.resolve_name!(tag_name, guardian:) : nil
      end

      def ensure_tag_is_unique!(column:, tag_id:, tag_name:)
        return if tag_id.blank?
        return if column.board.columns.where(tag_id:).where.not(id: column.id).empty?

        raise Discourse::InvalidParameters.new(
                I18n.t("boards.errors.cannot_use_same_tag_multiple_times", tag_name: tag_name),
              )
      end

      def compact_positions!(board)
        board
          .columns
          .order(:position, :id)
          .each_with_index do |column, index|
            column.update!(position: index) if column.position != index
          end
      end
    end
  end
end
