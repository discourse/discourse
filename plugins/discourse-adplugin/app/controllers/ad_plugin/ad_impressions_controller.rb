# frozen_string_literal: true
module AdPlugin
  class AdImpressionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    CREATE_RATE_LIMIT_KEY = "ad-impressions-create"
    CREATE_RATE_LIMIT_PER_MINUTE = 30
    CREATE_RATE_LIMIT_SECONDS = 1.minute

    skip_before_action :check_xhr, :preload_json, only: [:update]

    def create
      raise Discourse::InvalidAccess unless SiteSetting.ad_plugin_enable_tracking

      rate_limit_key =
        if current_user
          CREATE_RATE_LIMIT_KEY
        else
          "#{CREATE_RATE_LIMIT_KEY}-#{request.ip}"
        end

      RateLimiter.new(
        current_user,
        rate_limit_key,
        CREATE_RATE_LIMIT_PER_MINUTE,
        CREATE_RATE_LIMIT_SECONDS,
      ).performed!

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
                 error: I18n.t("errors.already_clicked"),
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
