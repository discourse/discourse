# frozen_string_literal: true

module DiscourseWorkflows
  class CredentialsController < ::SuperAdmin::SuperAdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::Credential::List.call(service_params) do |result|
        on_success do |credentials:, load_more_url:, total_rows:|
          render json: {
                   credentials:
                     serialize_data(credentials, DiscourseWorkflows::CredentialSerializer),
                   meta: { total_rows: total_rows, load_more_url: load_more_url }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def create
      DiscourseWorkflows::Credential::Create.call(service_params) do |result|
        on_success do |credential:|
          render_serialized(
            credential,
            DiscourseWorkflows::CredentialSerializer,
            root: "credential",
            status: :created,
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:valid_credential_type) do
          render(json: failed_json.merge(errors: ["Invalid credential type"]), status: :bad_request)
        end
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_errors(:credential) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def update
      DiscourseWorkflows::Credential::Update.call(
        service_params.deep_merge(params: { credential_id: params[:id] }),
      ) do |result|
        on_success do |credential:|
          render_serialized(
            credential,
            DiscourseWorkflows::CredentialSerializer,
            root: "credential",
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:credential) { raise Discourse::NotFound }
        on_model_errors(:credential) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def destroy
      DiscourseWorkflows::Credential::Destroy.call(
        service_params.deep_merge(params: { credential_id: params[:id] }),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:credential_not_in_use) do
          render(
            json:
              failed_json.merge(
                type: "credential_in_use",
                referencing_workflows: result[:referencing_workflows],
              ),
            status: :unprocessable_entity,
          )
        end
        on_model_not_found(:credential) { raise Discourse::NotFound }
      end
    end
  end
end
