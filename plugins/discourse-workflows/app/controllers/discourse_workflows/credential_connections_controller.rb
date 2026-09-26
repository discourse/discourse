# frozen_string_literal: true

module DiscourseWorkflows
  class CredentialConnectionsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    before_action :rate_limit_connection, only: :create

    def create
      Credential::Connect.call(
        service_params.deep_merge(params: { credential_id: params[:credential_id] }),
      ) do
        on_success do |credential:|
          render json: { credential: CredentialSerializer.new(credential, root: false).as_json }
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_not_found(:credential) { raise Discourse::NotFound }
        on_exceptions(Oauth2Provider::Error) do |error|
          render json: failed_json.merge(errors: [error.message]), status: :unprocessable_entity
        end
      end
    end

    private

    def rate_limit_connection
      RateLimiter.new(current_user, "workflow_oauth_connect", 10, 1.minute).performed!
    end
  end
end
