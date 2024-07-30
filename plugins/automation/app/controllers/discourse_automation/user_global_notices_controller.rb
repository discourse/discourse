# frozen_string_literal: true

module DiscourseAutomation
  class UserGlobalNoticesController < ApplicationController
    requires_plugin DiscourseAutomation::PLUGIN_NAME
    requires_login

    def destroy
      notice =
        DiscourseAutomation::UserGlobalNotice.find_by(user_id: current_user.id, id: params[:id])

      raise Discourse::NotFound unless notice

      notice.destroy!

      head :no_content
    end
  end
end
