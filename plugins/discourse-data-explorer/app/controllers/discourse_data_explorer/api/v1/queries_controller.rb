# frozen_string_literal: true

module DiscourseDataExplorer
  module Api
    module V1
      # JSON:API modernization spike (Graphiti). Read-only for now.
      class QueriesController < ::ApplicationController
        requires_plugin DiscourseDataExplorer::PLUGIN_NAME

        # Spike: deliberately open + non-XHR so we can curl and focus purely on
        # the JSON:API document. Real Guardian/auth wiring is a later step.
        skip_before_action :check_xhr, :redirect_to_login_if_required, raise: false

        # Graphiti's strict client-input errors need explicit status mapping
        # (graphiti-rails only registers a handful; the rest become 500s).
        # Its RescueRegistry mechanism renders error bodies via Rails'
        # exceptions_app — which Discourse replaces with
        # Middleware::DiscoursePublicExceptions — so registered handlers get
        # the right status but never render the JSON:API errors document.
        # Handle them at the controller level instead, Discourse-style.
        CLIENT_INPUT_ERRORS = [
          Graphiti::Errors::UnknownAttribute,
          Graphiti::Errors::InvalidAttributeAccess,
          Graphiti::Errors::UnsupportedOperator,
          Graphiti::Errors::InvalidFilterValue,
          Graphiti::Errors::UnsupportedSort,
          Graphiti::Errors::UnsupportedPageSize,
          Graphiti::Errors::InvalidInclude,
        ].freeze

        rescue_from(*CLIENT_INPUT_ERRORS) do |e|
          render json: {
                   errors: [
                     {
                       code: "bad_request",
                       status: "400",
                       title: "Request error",
                       detail: e.message,
                     },
                   ],
                 },
                 status: :bad_request,
                 content_type: "application/vnd.api+json"
        end

        def index
          render jsonapi: QueryResource.all(params)
        end

        def show
          render jsonapi: QueryResource.find(params)
        end
      end
    end
  end
end
