# frozen_string_literal: true

module DiscourseDataExplorer
  class QueriesController < JsonApiKit::BaseController
    requires_plugin PLUGIN_NAME

    before_action :ensure_admin

    resource :queries

    def create
      CreateQuery.call(service_params) do |result|
        on_success { |query:| render_document(query, status: :created) }
        on_failed_policy(:can_create_query) { raise Discourse::InvalidAccess }
        on_failed_contract { |contract| render_validation_errors(contract.errors) }
        on_failed_policy(:requested_groups_exist) { raise Discourse::NotFound }
        on_model_errors(:query) { |query| render_validation_errors(query.errors) }
        on_exceptions(ActiveRecord::RecordInvalid) do |error|
          render_validation_errors(error.record.errors)
        end
        on_failure { render_service_failure(result) }
      end
    end
  end
end
