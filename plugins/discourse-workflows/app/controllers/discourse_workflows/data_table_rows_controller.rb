# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableRowsController < ::SuperAdmin::SuperAdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::DataTableRow::Get.call(
        service_params.deep_merge(params: { data_table_id: params[:data_table_id] }),
      ) do |result|
        on_success do |query_result:|
          render json: { rows: query_result[:rows], count: query_result[:count] }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:data_table) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_errors(:query) { |model| render_invalid_model(model) }
      end
    end

    def create
      DiscourseWorkflows::DataTableRow::Insert.call(
        service_params.deep_merge(params: { data_table_id: params[:data_table_id] }),
      ) do |result|
        on_success { |row:| render json: { row: row }, status: :created }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:data_table) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:within_storage_limit) { render_storage_limit_exceeded }
        on_model_errors(:row_input) { |model| render_invalid_model(model) }
      end
    end

    def update_bulk
      DiscourseWorkflows::DataTableRow::Update.call(
        service_params.deep_merge(params: { data_table_id: params[:data_table_id] }),
      ) do |result|
        on_success { |updated_count:| render json: { updated_count: updated_count } }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:data_table) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:within_storage_limit) { render_storage_limit_exceeded }
        on_model_errors(:query) { |model| render_invalid_model(model) }
        on_model_errors(:row_input) { |model| render_invalid_model(model) }
      end
    end

    def update
      DiscourseWorkflows::DataTableRow::UpdateSingle.call(
        service_params.deep_merge(
          params: {
            data_table_id: params[:data_table_id],
            row_id: params[:id],
          },
        ),
      ) do |result|
        on_success { |row:| render json: { row: row } }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:data_table) { raise Discourse::NotFound }
        on_model_not_found(:existing_row) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:within_storage_limit) { render_storage_limit_exceeded }
        on_model_errors(:row_input) { |model| render_invalid_model(model) }
      end
    end

    def destroy
      DiscourseWorkflows::DataTableRow::Destroy.call(
        service_params.deep_merge(
          params: {
            data_table_id: params[:data_table_id],
            row_id: params[:id],
          },
        ),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:data_table) { raise Discourse::NotFound }
        on_model_not_found(:row) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def destroy_bulk
      DiscourseWorkflows::DataTableRow::Destroy.call(
        service_params.deep_merge(params: { data_table_id: params[:data_table_id] }),
      ) do |result|
        on_success { |deleted_count:| render json: { deleted_count: deleted_count } }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:data_table) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_errors(:query) { |model| render_invalid_model(model) }
      end
    end

    private

    def render_storage_limit_exceeded
      render json:
               failed_json.merge(
                 errors: [I18n.t("discourse_workflows.errors.storage_limit_exceeded")],
               ),
             status: :bad_request
    end

    def render_invalid_model(model)
      render json: failed_json.merge(errors: model.errors.full_messages), status: :bad_request
    end
  end
end
