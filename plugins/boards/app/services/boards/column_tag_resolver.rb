# frozen_string_literal: true

module Boards
  module ColumnTagResolver
    class << self
      def resolve_tag_ids(current_tag_ids:, column:)
        current_tag_ids = existing_tag_ids(normalize_tag_ids(current_tag_ids))
        board_column_tag_ids =
          existing_tag_ids(column.board.columns.filter_map { |c| c.tag_id.presence }.uniq)

        if column.tag_id.present?
          return current_tag_ids if board_column_tag_ids.exclude?(column.tag_id)

          sibling_tag_ids = board_column_tag_ids - [column.tag_id]
          (current_tag_ids - sibling_tag_ids + [column.tag_id]).uniq
        else
          current_tag_ids - board_column_tag_ids
        end
      end

      def normalize_tag_ids(values)
        Array(values).compact_blank.map { |value| Integer(value) }.reject(&:zero?).uniq
      rescue ArgumentError, TypeError
        raise Discourse::InvalidParameters.new(
                I18n.t("boards.errors.unknown_tag_ids", tag_ids: Array(values).join(",")),
              )
      end

      private

      def existing_tag_ids(tag_ids)
        return [] if tag_ids.empty?

        Tag.where(id: tag_ids).pluck(:id)
      end
    end
  end
end
