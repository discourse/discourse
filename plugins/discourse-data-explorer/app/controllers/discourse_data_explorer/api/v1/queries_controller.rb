# frozen_string_literal: true

module DiscourseDataExplorer
  module Api
    module V1
      # JSON:API modernization spike (Graphiti). Read-only for now.
      class QueriesController < ::ApplicationController
        requires_plugin DiscourseDataExplorer::PLUGIN_NAME

        # Authorization is row-level, via Guardian in QueryResource#base_scope
        # (admin → all, member → group-bound queries, anonymous → nothing).
        # The skips give public-API semantics: anonymous gets an empty 200,
        # not a login redirect, and no XHR requirement.
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

        # Set by the keyset branch of ApplicationResource's paginate block
        # (the resource reaches us through Graphiti's context).
        attr_accessor :next_page_cursor

        def index
          records = QueryResource.all(params)
          records.data # force resolution so pagination runs before we build meta

          if next_page_cursor
            render jsonapi: records, meta: { page: { next_cursor: next_page_cursor } }
          else
            render jsonapi: records
          end
        end

        def show
          render jsonapi: QueryResource.find(params)
        end

        def create
          query = QueryResource.build(params)

          if query.save
            render jsonapi: query, status: :created
          else
            render jsonapi_errors: query
          end
        end
      end
    end
  end
end
