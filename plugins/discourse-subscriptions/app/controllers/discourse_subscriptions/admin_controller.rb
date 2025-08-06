# frozen_string_literal: true

module DiscourseSubscriptions
  class AdminController < ::Admin::AdminController
    requires_plugin DiscourseSubscriptions::PLUGIN_NAME

    def index
      head 200
    end

    def refresh_campaign
      Jobs.enqueue(:manually_update_campaign_data)
      render json: success_json
    end

    def create_campaign
      begin
        DiscourseSubscriptions::Campaign.new.create_campaign
        render json: success_json
      rescue => e
        render_json_error e.message
      end
    end
  end
end
