# frozen_string_literal: true

module Boards
  module Api
    class TopicMovesController < ::Boards::BaseController
      before_action :ensure_logged_in

      def create
        Boards::MoveTopicToColumn.call(
          **service_params.deep_merge(params: { client_id: message_bus_client_id }),
        ) do
          on_success do |card:|
            render json: {
                     card: CardSerializer.new(card, root: false, scope: guardian).as_json,
                   },
                   status: :created
          end
          on_model_not_found(:board) { raise Discourse::NotFound }
          on_model_not_found(:topic) { raise Discourse::NotFound }
          on_model_not_found(:column) do
            raise Discourse::NotFound.new(I18n.t("boards.errors.column_not_found"))
          end
          on_failed_policy(:can_write) { raise Discourse::InvalidAccess }
          on_failed_policy(:can_see_topic) { raise Discourse::InvalidAccess }
          on_failed_policy(:can_edit_topic) { raise Discourse::InvalidAccess }
          on_failed_policy(:topic_matches_constraints) do
            render json:
                     failed_json.merge(
                       errors: [I18n.t("boards.errors.topic_does_not_match_constraints")],
                     ),
                   status: :unprocessable_entity
          end
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end
    end
  end
end
