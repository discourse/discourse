# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryGroupRelationshipsController < JsonApiKit::RelationshipsController
    requires_plugin PLUGIN_NAME

    before_action :ensure_admin

    resource :queries
    relationship :groups

    def create
      AddQueryGroups.call(service_params) do |result|
        on_success { head :no_content }
        on_failed_policy(:can_add_query_groups) { raise Discourse::InvalidAccess }
        on_model_not_found(:query) { raise Discourse::NotFound }
        on_failed_contract { |contract| render_validation_errors(contract.errors) }
        on_failed_policy(:requested_groups_exist) { raise Discourse::NotFound }
        on_failure { render_service_failure(result) }
      end
    end

    def update
      ReplaceQueryGroups.call(service_params) do |result|
        on_success { head :no_content }
        on_failed_policy(:can_replace_query_groups) { raise Discourse::InvalidAccess }
        on_model_not_found(:query) { raise Discourse::NotFound }
        on_failed_contract { |contract| render_validation_errors(contract.errors) }
        on_failed_policy(:requested_groups_exist) { raise Discourse::NotFound }
        on_failure { render_service_failure(result) }
      end
    end

    def destroy
      RemoveQueryGroups.call(service_params) do |result|
        on_success { head :no_content }
        on_failed_policy(:can_remove_query_groups) { raise Discourse::InvalidAccess }
        on_model_not_found(:query) { raise Discourse::NotFound }
        on_failed_contract { |contract| render_validation_errors(contract.errors) }
        on_failure { render_service_failure(result) }
      end
    end
  end
end
