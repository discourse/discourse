# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumnsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def create
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

    def rename
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

    def destroy
      DiscourseWorkflows::DataTableColumn::Destroy.call(
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

    private

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
