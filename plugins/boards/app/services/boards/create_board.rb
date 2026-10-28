# frozen_string_literal: true

module Boards
  class CreateBoard
    include Service::Base

    params do
      attribute :name, :string

      validates :name, presence: true
    end

    policy :can_manage

    transaction do
      model :board, :create_board
      step :replace_columns
      step :create_acl
      step :create_history
    end

    private

    def can_manage(guardian:)
      guardian.can_create_board?
    end

    def create_board(guardian:)
      raw = context[:raw_board_params]&.dup || {}
      if raw.key?("tag_names")
        raw["tag_ids"] = VisibleTagResolver.resolve_names!(raw.delete("tag_names"), guardian:)
      end
      board = Board.new(raw.except("columns", "acl", "owner_user_ids"))
      board.created_by_id = guardian.user.id
      board.updated_by_id = guardian.user.id
      board.save!
      board
    end

    def replace_columns(board:, guardian:)
      raw = context[:raw_board_params] || {}
      ColumnsReplacer.replace!(
        board:,
        columns_payload: raw["columns"] || [],
        user: guardian.user,
        guardian:,
      )
    end

    def create_acl(board:, guardian:)
      raw = context[:raw_board_params] || {}
      flattened_acl = raw["acl"] || []

      AccessControlList::Apply.call(
        guardian:,
        params: {
          acl_target_type: board.class.name,
          acl_target_id: board.id,
          acl_entries: flattened_acl,
          source: Boards::PLUGIN_NAME,
          initial_owner_user_id: guardian.user.id,
          owner_user_ids: raw["owner_user_ids"],
        },
      ) do |result|
        on_failure do
          Rails.logger.warn(
            "Failed to create ACL for board #{board.id} (#{flattened_acl.to_json}): #{result.inspect_steps}",
          )
          fail!(I18n.t("boards.board.errors.acl_create_failed"))
        end
      end
    end

    def create_history(board:, guardian:)
      BoardHistory.create!(
        board:,
        acting_user: guardian.user,
        action: BoardHistory.actions[:board_created],
      )
    end
  end
end
