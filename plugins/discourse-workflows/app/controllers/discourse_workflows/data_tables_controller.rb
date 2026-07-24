# frozen_string_literal: true

module DiscourseWorkflows
  class DataTablesController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::DataTable::List.call(service_params) do |result|
        on_success do |data_tables:, total_rows:, table_sizes: {}, load_more_url:|
          render json: {
                   data_tables:
                     serialize_data(
                       data_tables,
                       DiscourseWorkflows::DataTableSerializer,
                       table_sizes: table_sizes,
                     ),
                   meta: { total_rows: total_rows, load_more_url: load_more_url }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def show
      DiscourseWorkflows::DataTable::Show.call(
        service_params.deep_merge(params: { data_table_id: params[:id] }),
      ) do |result|
        on_success do |data_table:|
          render_serialized(data_table, DiscourseWorkflows::DataTableSerializer, root: "data_table")
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:data_table) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def create
      DiscourseWorkflows::DataTable::Create.call(service_params) do |result|
        on_success do |data_table:|
          render_serialized(
            data_table,
            DiscourseWorkflows::DataTableSerializer,
            root: "data_table",
            status: :created,
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_errors(:data_table) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def update
      DiscourseWorkflows::DataTable::Update.call(
        service_params.deep_merge(params: { data_table_id: params[:id] }),
      ) do |result|
        on_success do |data_table:|
          render_serialized(data_table, DiscourseWorkflows::DataTableSerializer, root: "data_table")
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
        on_model_errors(:data_table) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def destroy
      DiscourseWorkflows::DataTable::Destroy.call(
        service_params.deep_merge(params: { data_table_id: params[:id] }),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:data_table_not_in_use) do
          render(
            json:
              failed_json.merge(
                type: "data_table_in_use",
                referencing_workflows:
                  result[:referencing_workflows]
                    .pluck(:id, :name)
                    .map { |id, name| { id:, name: } },
              ),
            status: :unprocessable_entity,
          )
        end
        on_model_not_found(:data_table) { raise Discourse::NotFound }
      end
    end
  end
end
