# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AdminDashboardHighlightsController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        raise Discourse::NotFound if !DiscourseAi::AdminDashboard.highlights_enabled?

        highlight =
          DiscourseAi::AdminDashboard::HighlightGenerator.generate(
            start_date: params[:start_date],
            end_date: params[:end_date],
            period: params[:period],
          )

        render json: { highlight: highlight }
      end
    end
  end
end
