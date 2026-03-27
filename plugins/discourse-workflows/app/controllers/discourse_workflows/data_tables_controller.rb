# frozen_string_literal: true

module DiscourseWorkflows
  class DataTablesController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    rescue_from DiscourseWorkflows::DataTableValidationError,
                with: :render_invalid_data_table_request

    def index
      DiscourseWorkflows::DataTable::List.call(service_params) do |result|
        on_success do |data_tables:, load_more_url:, total_rows:, table_sizes:|
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
        on_model_errors(:column) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def rename_column
      DiscourseWorkflows::DataTableColumn::Rename.call(
        service_params.deep_merge(
          params:
            column_rename_params.merge(
              data_table_id: params[:data_table_id],
              column_id: params[:column_id],
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
        on_model_not_found(:column) { raise Discourse::NotFound }
        on_model_errors(:column) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def move_column
      DiscourseWorkflows::DataTableColumn::Move.call(
        service_params.deep_merge(
          params:
            column_move_params.merge(
              data_table_id: params[:data_table_id],
              column_id: params[:column_id],
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
        on_model_not_found(:column) { raise Discourse::NotFound }
      end
    end

    def destroy_column
      DiscourseWorkflows::DataTableColumn::Delete.call(
        service_params.deep_merge(
          params: {
            data_table_id: params[:data_table_id],
            column_id: params[:column_id],
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
        on_model_not_found(:column) { raise Discourse::NotFound }
      end
    end

    def destroy
      DiscourseWorkflows::DataTable::Delete.call(
        service_params.deep_merge(params: { data_table_id: params[:id] }),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:data_table) { raise Discourse::NotFound }
      end
    end

    def rows
      DiscourseWorkflows::DataTableRow::Get.call(
        service_params.deep_merge(
          params: row_query_params.merge(data_table_id: params[:data_table_id]),
        ),
      ) do |result|
        on_success { |rows:, count:| render json: { rows: rows, count: count } }
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

    def insert_row
      DiscourseWorkflows::DataTableRow::Insert.call(
        service_params.deep_merge(
          params: row_data_params.merge(data_table_id: params[:data_table_id]),
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
      end
    end

    def update_rows
      DiscourseWorkflows::DataTableRow::Update.call(
        service_params.deep_merge(
          params: row_mutation_params.merge(data_table_id: params[:data_table_id]),
        ),
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
      end
    end

    def update_row
      DiscourseWorkflows::DataTableRow::UpdateSingle.call(
        service_params.deep_merge(
          params: row_data_params.merge(data_table_id: params[:data_table_id], row_id: params[:id]),
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
        on_model_not_found(:row) { raise Discourse::NotFound }
      end
    end

    def destroy_row
      DiscourseWorkflows::DataTableRow::DestroySingle.call(
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
      end
    end

    def delete_rows
      DiscourseWorkflows::DataTableRow::Delete.call(
        service_params.deep_merge(
          params: row_filter_params.merge(data_table_id: params[:data_table_id]),
        ),
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
      end
    end

    private

    def create_data_table_params
      p = params.slice(:name)
      p = p.respond_to?(:to_unsafe_h) ? p.to_unsafe_h : p.to_h
      cols = params[:columns]
      cols = cols.values if cols.is_a?(ActionController::Parameters)
      p["columns"] = Array(cols).map { |c| c.respond_to?(:to_unsafe_h) ? c.to_unsafe_h : c.to_h }
      p
    end

    def update_data_table_params
      p = params.slice(:name)
      p.respond_to?(:to_unsafe_h) ? p.to_unsafe_h : p.to_h
    end

    def column_create_params
      p = params.slice(:name, :column_type)
      p.respond_to?(:to_unsafe_h) ? p.to_unsafe_h : p.to_h
    end

    def column_rename_params
      p = params.slice(:name)
      p.respond_to?(:to_unsafe_h) ? p.to_unsafe_h : p.to_h
    end

    def column_move_params
      p = params.slice(:position)
      p.respond_to?(:to_unsafe_h) ? p.to_unsafe_h : p.to_h
    end

    def row_query_params
      extract_row_params(:filter, :limit, :offset, :sort_by, :sort_direction, deep_keys: [:filter])
    end

    def row_data_params
      extract_row_params(:data, deep_keys: [:data])
    end

    def row_mutation_params
      extract_row_params(:filter, :data, deep_keys: %i[filter data])
    end

    def row_filter_params
      extract_row_params(:filter, deep_keys: [:filter])
    end

    def extract_row_params(*keys, deep_keys: [])
      result = params.slice(*keys)
      result = result.respond_to?(:to_unsafe_h) ? result.to_unsafe_h : result.to_h
      deep_keys.each do |key|
        value = params[key]
        result[key.to_s] = (
          if value.is_a?(ActionController::Parameters)
            value.to_unsafe_h
          else
            value
          end
        ) if value.present?
      end
      result
    end

    def render_invalid_data_table_request(exception)
      render json: failed_json.merge(errors: [exception.message]), status: :bad_request
    end
  end
end
