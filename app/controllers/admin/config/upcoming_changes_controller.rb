# frozen_string_literal: true
class Admin::Config::UpcomingChangesController < Admin::AdminController
  def index
    render json:
             SiteSetting
               .all_settings(
                 only_upcoming_changes: true,
                 include_hidden: true,
                 include_locale_setting: false,
               )
               .each { |setting| setting[:value] = setting[:value] == "true" } if request.xhr?
  end
end
