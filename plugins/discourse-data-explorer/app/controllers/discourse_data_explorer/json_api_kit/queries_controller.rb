# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # JSON:API Kit endpoint for Query. All declarations live on the resource
    # class (docs/resource-design.md); only the write (create) carries bespoke
    # logic, via Service::Base.
    class QueriesController < BaseController
      resource QueryResource

      # Writes stay explicit and bespoke (Service::Base owns validation/policy/persistence).
      def create
        DiscourseDataExplorer::Query::Create.call(service_params) do
          on_success { |query:| render_resource(query, status: :created) }
          on_failed_policy(:can_create_query) { raise Discourse::InvalidAccess }
          on_failed_contract { |contract| render_validation_errors(contract.errors) }
          on_model_errors(:query) { |query| render_validation_errors(query.errors) }
          on_failure { render_errors(["Query could not be created"]) }
        end
      end
    end
  end
end
