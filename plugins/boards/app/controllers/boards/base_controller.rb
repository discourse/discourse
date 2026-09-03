# frozen_string_literal: true

module Boards
  class BaseController < ::ApplicationController
    requires_plugin Boards::PLUGIN_NAME

    before_action :ensure_plugin_enabled

    private

    def ensure_plugin_enabled
      raise Discourse::InvalidAccess.new unless SiteSetting.boards_enabled?
    end

    def find_board!
      board_id = params[:board_id] || params[:id]
      @board = Boards::Board.find_by(id: board_id)
      raise Discourse::NotFound.new(I18n.t("boards.errors.board_not_found")) if @board.blank?
    end

    def ensure_board_read!
      unless guardian.can_read_boards_board?(@board)
        raise Discourse::InvalidAccess.new(I18n.t("boards.errors.board_read_forbidden"))
      end
    end

    def build_tag_name_map(*boards)
      all_tag_ids = boards.flat_map { |b| b.tag_ids + b.columns.filter_map(&:tag_id) }.uniq
      return {} if all_tag_ids.empty?
      Tag.visible(guardian).where(id: all_tag_ids).pluck(:id, :name).to_h
    end

    def card_mutation_params
      params.require(:card).permit(
        :topic_id,
        :column_id,
        :title,
        :notes,
        :after_card_id,
        :assigned_to_name,
        tag_ids: [],
        tag_names: [],
      )
    end

    def constraint_fix_params
      params.permit(constraint_fix: [:category_id, tag_names: []])[:constraint_fix]
    end

    def column_mutation_params
      params.require(:column).permit(
        :title,
        :icon,
        :default_sort,
        :tag_name,
        :move_to_category_id,
        :move_to_assigned,
        :move_to_status,
        :color,
      )
    end

    def message_bus_client_id
      params[:client_id]
    end

    def board_mutation_params
      params.require(:board).permit(
        :name,
        :slug,
        :require_confirmation,
        :show_tags,
        :card_style,
        :show_topic_thumbnail,
        acl: %i[id type permission],
        category_ids: [],
        tag_names: [],
        columns: %i[
          id
          title
          icon
          position
          default_sort
          tag_name
          move_to_category_id
          move_to_assigned
          move_to_status
        ],
      )
    end
  end
end
