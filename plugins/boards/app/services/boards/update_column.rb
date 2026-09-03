# frozen_string_literal: true

module Boards
  class UpdateColumn
    include Service::Base

    params do
      attribute :board_id, :integer
      attribute :id, :integer
      attribute :title, :string
      attribute :icon, :string
      attribute :color, :string
      attribute :default_sort, :string
      attribute :tag_name, :string
      attribute :move_to_category_id, :integer
      attribute :move_to_assigned, :string
      attribute :move_to_status, :string
      attribute :client_id, :string

      validates :board_id, presence: true
      validates :id, presence: true
      validates :title, presence: true
      validates :color, format: { with: /\A(\h{3}|\h{6})\z/ }, allow_nil: true
    end

    model :board
    policy :can_manage
    model :column

    transaction do
      step :update_column
      step :create_histories
    end

    step :publish_update

    private

    def fetch_board(params:)
      Board.find_by(id: params.board_id)
    end

    def can_manage(guardian:, board:)
      guardian.can_manage_boards_board?(board)
    end

    def fetch_column(board:, params:)
      board.columns.find_by(id: params.id)
    end

    def update_column(column:, params:, guardian:)
      ColumnMutator.apply!(column:, attributes: params.to_hash, guardian:)
    end

    def create_histories(board:, column:, guardian:)
      changes = history_changes(column)

      if changes.key?(:title)
        previous_title, new_title = changes.delete(:title)
        BoardHistory.create!(
          board:,
          column:,
          acting_user: guardian.user,
          action: :column_renamed,
          details: {
            previous_value: previous_title,
            new_value: new_title,
          },
        )
      end

      if changes.present?
        BoardHistory.create!(
          board:,
          column:,
          acting_user: guardian.user,
          action: :column_edited,
          details: {
            previous_values: changes.transform_values(&:first),
            new_values: changes.transform_values(&:last),
          },
        )
      end
    end

    def publish_update(board:, params:)
      Publisher.publish_board_updated!(board, client_id: params.client_id)
    end

    def history_changes(column)
      column
        .saved_changes
        .slice(
          "title",
          "icon",
          "color",
          "default_sort",
          "tag_id",
          "move_to_category_id",
          "move_to_assigned",
          "move_to_status",
        )
        .transform_keys(&:to_sym)
    end
  end
end
