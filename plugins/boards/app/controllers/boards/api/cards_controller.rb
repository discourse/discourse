# frozen_string_literal: true

module Boards
  module Api
    class CardsController < ::Boards::BaseController
      before_action :ensure_logged_in

      def create
        Boards::CreateCard.call(
          service_params.deep_merge(
            params: card_mutation_params.to_h.merge(board_id: params[:board_id]),
            options: {
              constraint_fix: constraint_fix_params,
            },
          ),
        ) do
          on_success do |card:, board:|
            payload = CardSerializer.new(card, root: false, scope: guardian).as_json
            publish_payload = CardSerializer.new(card, root: false).as_json
            Publisher.publish_card_created!(
              board,
              publish_payload,
              client_id: message_bus_client_id,
            )
            if card.topic.present?
              Publisher.publish_topic_memberships_changed!(
                card.topic,
                client_id: message_bus_client_id,
                # Constraint fixes may change the topic's category or tags, so the post
                # stream must be refreshed along with the topic metadata.
                refresh_stream: params[:constraint_fix].present?,
              )
            end
            Jobs.enqueue(Jobs::Boards::CardPostProcess, card_id: card.id, title: card.title)
            render json: { card: payload }, status: :created
          end
          on_model_not_found(:board) { raise Discourse::NotFound }
          on_model_not_found(:column) do
            raise Discourse::NotFound.new(I18n.t("boards.errors.column_not_found"))
          end
          on_failed_policy(:can_write) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def update
        raw_params = card_mutation_params.to_h

        Boards::UpdateCard.call(
          service_params.deep_merge(
            params: raw_params.merge(board_id: params[:board_id], id: params[:id]),
            options: {
              raw_card_params: raw_params,
              constraint_fix: constraint_fix_params,
            },
          ),
        ) do
          on_success do |card:, board:, original_column_id:, adopted_floater_id:|
            card.topic&.reload
            response = CardSerializer.new(card, root: false, scope: guardian).as_json
            publish_response = CardSerializer.new(card, root: false).as_json

            if adopted_floater_id
              Publisher.publish_card_deleted!(
                board,
                adopted_floater_id,
                client_id: message_bus_client_id,
              )
              Publisher.publish_card_created!(
                board,
                publish_response,
                client_id: message_bus_client_id,
              )
            elsif card.column_id != original_column_id
              Publisher.publish_card_moved!(
                board,
                publish_response,
                client_id: message_bus_client_id,
              )
            else
              Publisher.publish_card_updated!(
                board,
                publish_response,
                client_id: message_bus_client_id,
              )
            end

            if card.topic.present? && card.column_id != original_column_id
              Publisher.publish_topic_memberships_changed!(
                card.topic,
                client_id: message_bus_client_id,
                refresh_stream: params[:constraint_fix].present?,
              )
            end

            if raw_params.key?("title")
              Jobs.enqueue(Jobs::Boards::CardPostProcess, card_id: card.id, title: card.title)
            end

            render json: { card: response, adopted_floater_id: adopted_floater_id }
          end
          on_model_not_found(:board) { raise Discourse::NotFound }
          on_model_not_found(:card) do
            raise Discourse::NotFound.new(I18n.t("boards.errors.card_not_found"))
          end
          on_model_not_found(:column) do
            raise Discourse::NotFound.new(I18n.t("boards.errors.column_not_found"))
          end
          on_failed_policy(:can_write) { raise Discourse::InvalidAccess }
          on_failed_policy(:can_see_card_topic) { raise Discourse::NotFound }
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def clear
        Boards::ClearColumn.call(
          service_params.deep_merge(
            params: {
              board_id: params[:board_id],
              column_id: params[:column_id],
            },
          ),
        ) do
          on_success do |board:, column:|
            Publisher.publish_column_cleared!(board, column.id, client_id: message_bus_client_id)
            head :no_content
          end
          on_model_not_found(:board) { raise Discourse::NotFound }
          on_model_not_found(:column) do
            raise Discourse::NotFound.new(I18n.t("boards.errors.column_not_found"))
          end
          on_failed_policy(:can_write) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def destroy
        Boards::DestroyCard.call(
          service_params.deep_merge(params: { board_id: params[:board_id], id: params[:id] }),
        ) do
          on_success do |card:, board:|
            Publisher.publish_card_deleted!(board, card.id, client_id: message_bus_client_id)

            if card.topic.present?
              Publisher.publish_topic_memberships_changed!(
                card.topic,
                client_id: message_bus_client_id,
              )
            end

            head :no_content
          end
          on_model_not_found(:board) { raise Discourse::NotFound }
          on_model_not_found(:card) do
            raise Discourse::NotFound.new(I18n.t("boards.errors.card_not_found"))
          end
          on_failed_policy(:can_write) { raise Discourse::InvalidAccess }
          on_failed_policy(:can_see_card_topic) { raise Discourse::NotFound }
          on_failed_policy(:card_is_deletable) do
            render json: {
                     errors: [I18n.t("boards.errors.topic_covered_by_filter")],
                   },
                   status: :unprocessable_entity
          end
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def view
        Boards::ViewCard.call(service_params) do
          on_success { head :no_content }
          on_model_not_found(:card) { raise Discourse::NotFound }
          on_failed_policy(:is_logged_in) { raise Discourse::InvalidAccess }
          on_failed_policy(:can_view_card) { raise Discourse::InvalidAccess }
        end
      end
    end
  end
end
