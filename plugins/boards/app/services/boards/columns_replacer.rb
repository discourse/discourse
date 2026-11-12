# frozen_string_literal: true

module Boards
  class ColumnsReplacer
    def self.replace!(board:, columns_payload:, user:, guardian: user.guardian)
      Board.transaction do
        current_columns = board.columns.index_by(&:id)
        kept_column_ids = []
        used_tag_ids = []

        columns_needing_loose_card_tag_enforcement = []

        Array(columns_payload).each_with_index do |raw_col, index|
          col_payload = raw_col.with_indifferent_access
          id = col_payload[:id].presence&.to_i
          column = id && current_columns[id] ? current_columns[id] : board.columns.build

          tag_name = col_payload[:tag_name].presence
          resolved_tag_id = nil
          if tag_name
            resolved_tag_id = VisibleTagResolver.resolve_name!(tag_name, guardian:)
            if used_tag_ids.include?(resolved_tag_id)
              raise Discourse::InvalidParameters.new(
                      I18n.t(
                        "boards.errors.cannot_use_same_tag_multiple_times",
                        tag_name: tag_name,
                      ),
                    )
            end
            used_tag_ids << resolved_tag_id
          end

          previous_tag_id = column.tag_id

          column.assign_attributes(
            title: col_payload[:title],
            icon: col_payload[:icon],
            color: col_payload[:color].presence,
            tag_id: resolved_tag_id,
            default_sort: normalize_default_sort(col_payload[:default_sort]),
            move_to_category_id: col_payload[:move_to_category_id],
            move_to_assigned: col_payload[:move_to_assigned],
            move_to_status: col_payload[:move_to_status],
            position: index,
          )

          column.save!
          if previous_tag_id != column.tag_id
            columns_needing_loose_card_tag_enforcement << [column.id, previous_tag_id]
          end
          kept_column_ids << column.id
        end

        removed_columns = board.columns.where.not(id: kept_column_ids)
        removed_column_ids = removed_columns.pluck(:id)

        board.cards.where(column_id: removed_column_ids).delete_all if removed_column_ids.present?

        removed_columns.delete_all

        enforce_loose_card_tags!(board, columns_needing_loose_card_tag_enforcement)
      end
    end

    def self.enforce_loose_card_tags!(board, column_tag_changes)
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

    def self.normalize_default_sort(value)
      sort = value.presence || "priority"
      sort = sort.to_s
      return sort if Column.default_sorts.key?(sort)

      raise Discourse::InvalidParameters.new(
              I18n.t("boards.errors.invalid_column_sort", sort: sort),
            )
    end
    private_class_method :normalize_default_sort, :enforce_loose_card_tags!
  end
end
