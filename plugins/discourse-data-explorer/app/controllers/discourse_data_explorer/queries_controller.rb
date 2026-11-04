# frozen_string_literal: true

module DiscourseDataExplorer
  class QueriesController < JsonApiKit::BaseController
    requires_plugin PLUGIN_NAME

    before_action :ensure_admin

    resource :queries

    def create
      CreateQuery.call(service_params) do
        on_success { |query:| render_document(query, status: :created) }
        on_failed_policy(:can_create_query) { raise Discourse::InvalidAccess }
        on_failed_contract { |contract| render_validation_errors(contract.errors) }
        on_model_not_found(:groups) do |failure|
          raise failure.exception unless failure.exception.is_a?(ActiveRecord::RecordNotFound)
          raise Discourse::NotFound
        end
        on_model_errors(:query) { |query| render_validation_errors(query.errors) }
        on_model_not_found(:query) { |failure| raise failure.exception }
        on_exceptions(ActiveRecord::RecordInvalid) { |error| raise error }
      end
    end
  end
end
