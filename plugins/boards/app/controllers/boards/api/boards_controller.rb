# frozen_string_literal: true

module Boards
  module Api
    class BoardsController < ::Boards::BaseController
      DEFAULT_INDEX_PERMISSIONS = %w[view edit manage].freeze

      before_action :ensure_logged_in,
                    only: %i[create update destroy move_column constraint_preview]
      before_action :find_board!, only: %i[show]
      before_action :ensure_board_read!, only: %i[show]

      def index
        allowed_permissions =
          (
            if params[:allowed_permissions].present?
              params[:allowed_permissions]
                .split(",")
                .reject { |permission| !DEFAULT_INDEX_PERMISSIONS.include?(permission) }
            else
              DEFAULT_INDEX_PERMISSIONS
            end
          )

        boards =
          Boards::Board
            .includes(:columns, :created_by)
            .with_any_acl_permissions(guardian, allowed_permissions)
            .order(:name)
            .to_a
        tag_name_map = build_tag_name_map(*boards)
        render json: {
                 boards:
                   serialize_data(boards, Boards::BoardSerializer, root: false, tag_name_map:),
               }
      end

      def available
        allowed_permissions =
          (
            if params[:allowed_permissions].present?
              params[:allowed_permissions]
                .split(",")
                .reject { |permission| !DEFAULT_INDEX_PERMISSIONS.include?(permission) }
            else
              DEFAULT_INDEX_PERMISSIONS
            end
          )

        boards =
          Boards::Board
            .includes(:columns, :created_by)
            .with_any_acl_permissions(guardian, allowed_permissions)
            .order(:name)
            .to_a

        board_memberships = []
        if params[:topic_id].present?
          topic = Topic.find(params[:topic_id])
          guardian.ensure_can_see!(topic)
          board_memberships =
            Boards::TopicBoardMemberships.call(
              guardian: guardian,
              options: {
                topics: [topic],
              },
            ).single_topic_memberships || []
        end

        render json: {
                 boards:
                   serialize_data(
                     boards,
                     Boards::BasicBoardSerializer,
                     root: false,
                     board_memberships: board_memberships.flatten,
                   ),
               }
      end

      def show
        TopicSync.backfill_board(@board)

        # TODO (martin) We can further refactor this whole controller action
        # to be in a service, for now let's just log the view history,
        # it doesn't matter if this fails silently.
        Boards::ViewBoard.call(guardian:, params: { id: @board.id })

        topic_includes = %i[tags last_poster]
        topic_includes << :assignment if Topic.reflect_on_association(:assignment)
        cards =
          @board.cards.with_column.includes(:created_by, :assigned_to, topic: topic_includes).to_a
        visible_topic_ids = visible_topic_ids_for(cards)

        assignments_by_topic = preload_all_assignments(cards, visible_topic_ids)
        topic_users_by_topic = preload_topic_users(cards, visible_topic_ids)
        tags_by_id = preload_floater_card_tags(cards)

        tag_name_map = build_tag_name_map(@board)
        board_columns = @board.columns.to_a
        cards_by_column =
          cards
            .reject { |card| card.topic? && !visible_topic_ids.include?(card.topic_id) }
            .group_by(&:column_id)
        columns =
          serialize_data(
            board_columns,
            Boards::ColumnSerializer,
            root: false,
            tag_name_map:,
            cards_by_column:,
            assignments_by_topic:,
            topic_users_by_topic:,
            tags_by_id:,
          )

        render json: {
                 board:
                   serialize_board(
                     @board,
                     tag_name_map:,
                     include_acl: guardian.can_manage_boards_board?(@board),
                   ),
                 columns: columns,
               }
      end

      def create
        raw = board_mutation_params.to_h

        Boards::CreateBoard.call(guardian:, params: raw, raw_board_params: raw) do |result|
          on_success { |board:| render json: { board: serialize_board(board) }, status: :created }
          on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def update
        raw = board_mutation_params.to_h.except("columns")

        Boards::UpdateBoard.call(
          guardian:,
          params: raw.merge("id" => params[:id], "client_id" => params[:client_id]),
          raw_board_params: raw,
        ) do
          on_success do |board:, cards_removed_count:|
            response = {
              board: serialize_board(board, include_acl: guardian.can_manage_boards_board?(board)),
            }
            response[:cards_removed_count] = cards_removed_count if cards_removed_count.to_i > 0
            render json: response
          end
          on_model_not_found(:board) { raise Discourse::NotFound }
          on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def move_column
        Boards::MoveColumn.call(
          guardian:,
          params:
            params
              .permit(:column_id, :direction)
              .to_h
              .merge("board_id" => params[:id], "client_id" => message_bus_client_id),
        ) do
          on_success { |column_order:| render json: { column_order: column_order } }
          on_model_not_found(:board) { raise Discourse::NotFound }
          on_model_not_found(:column) do
            raise Discourse::NotFound.new(I18n.t("boards.errors.column_not_found"))
          end
          on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def constraint_preview
        board = Boards::Board.find(params[:id])
        guardian.ensure_can_manage_board!(board)

        new_category_ids = Array(params[:category_ids]).map(&:to_i).reject(&:zero?)
        new_tag_ids =
          if params[:tag_names].present?
            Tag.where(name: Array(params[:tag_names])).pluck(:id)
          else
            []
          end

        cat_empty = new_category_ids.empty?
        tag_empty = new_tag_ids.empty?

        if cat_empty && tag_empty
          count = 0
        else
          count =
            DB.query_single(
              <<~SQL,
              SELECT COUNT(*) FROM discourse_kanban_cards c
              JOIN topics t ON t.id = c.topic_id
              WHERE c.board_id = :board_id AND c.card_type = #{Boards::Card.card_types[:topic]}
                AND NOT (
                  (:cat_empty OR t.category_id = ANY(:category_ids))
                  AND (:tag_empty OR EXISTS (
                    SELECT 1 FROM topic_tags tt WHERE tt.topic_id = t.id AND tt.tag_id = ANY(:tag_ids)
                  ))
                )
            SQL
              board_id: board.id,
              category_ids: "{#{new_category_ids.join(",")}}",
              tag_ids: "{#{new_tag_ids.join(",")}}",
              cat_empty: cat_empty,
              tag_empty: tag_empty,
            ).first
        end

        render json: { cards_to_remove: count }
      end

      def destroy
        Boards::DestroyBoard.call(service_params) do
          on_success { head :no_content }
          on_model_not_found(:board) { raise Discourse::NotFound }
          on_failed_policy(:can_destroy) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def check_constraint_mismatches
        Boards::CheckBoardTopicConstraintMismatches.call(service_params) do
          on_success do |categories_needed:, tags_needed:|
            render json: {
                     categories_needed:,
                     tags_needed:,
                     constraints_need_fixing:
                       categories_needed.length.positive? || tags_needed.length.positive?,
                   }
          end
          on_model_not_found(:board) do
            raise Discourse::NotFound.new(I18n.t("boards.errors.board_not_found"))
          end
          on_model_not_found(:topic) { raise Discourse::NotFound }
          on_model_not_found(:target_column) do
            raise Discourse::NotFound.new(I18n.t("boards.errors.column_not_found"))
          end
          on_failed_policy(:can_view_topic) { raise Discourse::InvalidAccess }
          on_failed_policy(:can_edit_board) { raise Discourse::InvalidAccess }
        end
      end

      private

      def serialize_board(board, tag_name_map: nil, include_acl: false)
        serialize_data(
          board,
          Boards::BoardSerializer,
          root: false,
          tag_name_map: tag_name_map || build_tag_name_map(board),
          include_acl:,
        )
      end

      def serialize_boards(boards, tag_name_map:)
      end

      def preload_all_assignments(cards, visible_topic_ids)
        return {} unless defined?(Assignment)

        topic_ids = cards.select(&:topic?).map(&:topic_id).compact & visible_topic_ids
        return {} if topic_ids.empty?

        Assignment
          .where(topic_id: topic_ids, active: true, assigned_to_type: "User")
          .includes(:assigned_to)
          .group_by(&:topic_id)
      end

      def preload_topic_users(cards, visible_topic_ids)
        topics = cards.filter_map { |card| card.topic if visible_topic_ids.include?(card.topic_id) }
        TopicUser.lookup_for(current_user, topics)
      end

      def preload_floater_card_tags(cards)
        return {} unless SiteSetting.tagging_enabled

        tag_ids = cards.reject(&:topic?).flat_map(&:tag_ids).uniq
        return {} if tag_ids.empty?

        DiscourseTagging.filter_visible(Tag.where(id: tag_ids), guardian).index_by(&:id)
      end

      def visible_topic_ids_for(cards)
        topic_ids = cards.select(&:topic?).map(&:topic_id).uniq
        return [] if topic_ids.empty?

        Topic
          .listable_topics
          .secured(guardian)
          .where(id: topic_ids)
          .where.not(id: Category.where.not(topic_id: nil).select(:topic_id))
          .pluck(:id)
      end
    end
  end
end
