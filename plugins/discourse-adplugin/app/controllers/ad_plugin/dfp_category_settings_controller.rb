# frozen_string_literal: true

module AdPlugin
  class DfpCategorySettingsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    # Authenticated live-update refetch: returns only what the current viewer can
    # see, so clients can apply per-viewer visibility the broadcast cannot.
    def map
      render json: DfpCategorySetting.site_settings_for(guardian)
    end

    def index
      render_json_dump(
        dfp_category_settings: serialize_data(DfpCategorySetting.all, DfpCategorySettingSerializer),
      )
    end

    def create
      setting = DfpCategorySetting.new(dfp_category_setting_params)
      if setting.save
        DfpCategorySetting.publish_site_settings
        render_json_dump(serialize_data(setting, DfpCategorySettingSerializer), status: :created)
      else
        render_json_error(setting)
      end
    end

    def update
      setting = DfpCategorySetting.find_by(id: params[:id])
      raise Discourse::NotFound if setting.nil?

      if setting.update(dfp_category_setting_params)
        DfpCategorySetting.publish_site_settings
        render_json_dump(serialize_data(setting, DfpCategorySettingSerializer))
      else
        render_json_error(setting)
      end
    end

    def destroy
      setting = DfpCategorySetting.find_by(id: params[:id])
      raise Discourse::NotFound if setting.nil?

      setting.destroy!
      DfpCategorySetting.publish_site_settings
      head :no_content
    end

    private

    def dfp_category_setting_params
      params.permit(:category_id, :gam_adunit, :gam_keywords, :gtm_taxonomy)
    end
  end
end
