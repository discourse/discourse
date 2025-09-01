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
               .each { |setting|
                 setting[:value] = setting[:value] == "true"

                 if File.exist?(
                      Rails.root.join("public/images/upcoming_change_#{setting[:setting]}.png"),
                    )
                   setting[:upcoming_change][
                     :image_url
                   ] = "#{Discourse.base_url}/images/upcoming_change_#{setting[:setting]}.png"
                 end

                 if setting[:plugin]
                   plugin = Discourse.plugins_by_name[setting[:plugin]]

                   # TODO (martin) Maybe later we add a URL or something? Not sure
                   setting[:plugin] = plugin.humanized_name
                 end
               } if request.xhr?
  end
end
