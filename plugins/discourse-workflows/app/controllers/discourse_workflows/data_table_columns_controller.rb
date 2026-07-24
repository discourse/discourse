# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumnsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def create
      DiscourseWorkflows::DataTableColumn::Create.call(service_params) do |result|
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
        on_model_not_found(:data_table) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def rename
      DiscourseWorkflows::DataTableColumn::Rename.call(service_params) do |result|
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
      end
    end

    def destroy
      DiscourseWorkflows::DataTableColumn::Destroy.call(service_params) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:data_table) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end
  end
end
