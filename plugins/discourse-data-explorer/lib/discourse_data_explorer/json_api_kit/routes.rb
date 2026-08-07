# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # Draws a Kit endpoint's routes from the controller's own declarations, so the
    # routes file names an endpoint once and nothing is stated twice:
    #
    #   jsonapi_resource "queries", controller: "…/json_api_kit/queries"
    #
    # Reads are always routed (the framework implements them); writes are routed when
    # the controller implements them; and an `internal!` endpoint is placed under an
    # `internal/` segment, so the publication boundary is visible in the URL without
    # anyone having to remember to put it there (docs/resource-design.md §9).
    module Routes
      MEMBER_WRITES = { update: :patch, destroy: :delete }.freeze

      def jsonapi_resource(name, controller:)
        endpoint = "#{controller}_controller".camelize.constantize
        path = endpoint.internal? ? "internal/#{name}" : name.to_s
        member = "#{path}/:id"
        digits = { id: /\d+/ }

        get path => "#{controller}#index"
        get member => "#{controller}#show", :constraints => digits
        post path => "#{controller}#create" if implements?(endpoint, :create)
        MEMBER_WRITES.each do |action, verb|
          next if !implements?(endpoint, action)
          public_send(verb, member => "#{controller}##{action}", :constraints => digits)
        end
      end

      private

      # Only actions the endpoint defines itself — `index`/`show` come from the base
      # controller and are always routed.
      def implements?(endpoint, action) = endpoint.instance_methods(false).include?(action)
    end
  end
end
