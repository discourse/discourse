# frozen_string_literal: true
module AdPlugin
  class AdImpressionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def create
      impression =
        AdPlugin::AdImpression.create!(impression_params.merge(user_id: current_user&.id))

      render json: impression.as_json(only: %i[id ad_type placement user_id])
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
