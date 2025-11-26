# frozen_string_literal: true
module AdPlugin
  class AdImpressionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr, :preload_json, only: [:update]

    def create
      impression =
        AdPlugin::AdImpression.create!(impression_params.merge(user_id: current_user&.id))

      render json: impression.as_json(only: %i[id ad_type placement user_id])
    end

    def update
      impression = AdPlugin::AdImpression.find(params[:id])

      result = impression.record_click!

      if result
        render json: { success: true, clicked_at: impression.clicked_at }
      else
        render json: {
                 success: false,
                 error: "Click already recorded",
               },
               status: :unprocessable_entity
      end
    end

    private

    def impression_params
      required_params =
        params.require(:ad_plugin_impression).permit(:ad_type, :ad_plugin_house_ad_id, :placement)

      required_params[:ad_type] = required_params[:ad_type].to_i
      required_params
    end
  end
end
