# frozen_string_literal: true

module DiscourseWorkflows
  class DataTablesController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::DataTable::List.call(service_params) do |result|
        on_success do |data_tables:, total_rows:, table_sizes: {}, load_more_url: nil|
          render json: {
                   data_tables:
                     serialize_data(
                       data_tables,
                       DiscourseWorkflows::DataTableSerializer,
                       table_sizes: table_sizes,
                     ),
                   meta: {
                     total_rows_data_tables: total_rows,
                     load_more_data_tables: load_more_url,
                   }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
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
      end
    end

    def create
      DiscourseWorkflows::DataTable::Create.call(
        service_params.deep_merge(params: create_data_table_params),
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
        service_params.deep_merge(
          params: update_data_table_params.merge(data_table_id: params[:id]),
        ),
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
        on_model_errors(:data_table) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def create_column
      DiscourseWorkflows::DataTableColumn::Create.call(
        service_params.deep_merge(
          params: column_create_params.merge(data_table_id: params[:data_table_id]),
        ),
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
      end
    end

    def rename_column
      DiscourseWorkflows::DataTableColumn::Rename.call(
        service_params.deep_merge(
          params:
            column_rename_params.merge(
              data_table_id: params[:data_table_id],
              column_name: params[:column_name],
            ),
        ),
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
      end
    end

    def destroy_column
      DiscourseWorkflows::DataTableColumn::Delete.call(
        service_params.deep_merge(
          params: {
            data_table_id: params[:data_table_id],
            column_name: params[:column_name],
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
      end
    end

    def destroy
      DiscourseWorkflows::DataTable::Delete.call(
        service_params.deep_merge(params: { data_table_id: params[:id] }),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
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

    private

    def create_data_table_params
      p = unsafe_params(:name)
      cols = params[:columns]
      cols = cols.values if cols.is_a?(ActionController::Parameters)
      p["columns"] = Array(cols)
        .select { |c| c.is_a?(Hash) || c.is_a?(ActionController::Parameters) }
        .map { |c| unsafe_hash(c) }
      p
    end

    def update_data_table_params
      unsafe_params(:name)
    end

    def column_create_params
      unsafe_params(:name, :column_type)
    end

    def column_rename_params
      unsafe_params(:name)
    end

    def unsafe_params(*keys)
      unsafe_hash(params.slice(*keys))
    end

    def unsafe_hash(value)
      value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    end
  end
end
