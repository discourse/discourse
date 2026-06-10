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
