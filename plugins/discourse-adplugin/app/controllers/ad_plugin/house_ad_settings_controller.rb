# frozen_string_literal: true

module ::AdPlugin
  class HouseAdSettingsController < ::ApplicationController
    requires_plugin AdPlugin::PLUGIN_NAME

    def update
      HouseAdSetting.update(params[:id], params[:value])
      render json: success_json
    end
  end
end
