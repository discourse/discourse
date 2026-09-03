# frozen_string_literal: true

module Boards
  module Api
    class ColumnsController < ::Boards::BaseController
      before_action :ensure_logged_in

      def create
        Boards::CreateColumn.call(
          service_params.deep_merge(
            params:
              column_mutation_params.to_h.merge(
                board_id: params[:board_id],
                client_id: message_bus_client_id,
              ),
          ),
        ) do
          on_success do |column:|
            render json: {
                     column: ColumnSerializer.new(column, root: false, scope: guardian).as_json,
                   },
                   status: :created
          end
          on_model_not_found(:board) { raise Discourse::NotFound }
          on_model_not_found(:column) do |model_step|
            if model_step.exception
              render json: failed_json.merge(errors: [model_step.exception.message]),
                     status: :unprocessable_entity
            else
              raise Discourse::NotFound.new(I18n.t("boards.errors.column_not_found"))
            end
          end
          on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
          on_failed_contract do |contract|
            render json: failed_json.merge(errors: contract.errors.full_messages),
                   status: :bad_request
          end
          on_failure { render json: failed_json, status: :unprocessable_entity }
        end
      end

      def update
        Boards::UpdateColumn.call(
          service_params.deep_merge(
            params:
              column_mutation_params.to_h.merge(
                board_id: params[:board_id],
                id: params[:id],
                client_id: message_bus_client_id,
              ),
          ),
        ) do
          on_success do |column:|
            render json: {
                     column: ColumnSerializer.new(column, root: false, scope: guardian).as_json,
                   }
          end
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

      def destroy
        Boards::DestroyColumn.call(
          service_params.deep_merge(
            params: {
              board_id: params[:board_id],
              id: params[:id],
              client_id: message_bus_client_id,
            },
          ),
        ) do
          on_success { head :no_content }
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
    end
  end
end
