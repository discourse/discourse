# frozen_string_literal: true

class Admin::Config::AboutController < Admin::AdminController
  def index
  end

  def update
    settings_map = {}
    if general_settings = params[:general_settings]
      settings_map[:title] = general_settings[:name]
      settings_map[:site_description] = general_settings[:summary]
      settings_map[:about_banner_image] = general_settings[:about_banner_image]

      settings_map[:extended_site_description] = general_settings[:extended_description]
      settings_map[:short_site_description] = general_settings[:community_title]
      if settings_map[:extended_site_description].present?
        settings_map[:extended_site_description_cooked] = PrettyText.markdown(
          settings_map[:extended_site_description],
        )
      else
        settings_map[:extended_site_description_cooked] = ""
      end
    end

    if contact_information = params[:contact_information]
      settings_map[:community_owner] = contact_information[:community_owner]
      settings_map[:contact_email] = contact_information[:contact_email]
      settings_map[:contact_url] = contact_information[:contact_url]
      settings_map[:site_contact_username] = contact_information[:contact_username]
      settings_map[:site_contact_group_name] = contact_information[:contact_group_name]
    end

    if your_organization = params[:your_organization]
      settings_map[:company_name] = your_organization[:company_name]
      settings_map[:governing_law] = your_organization[:governing_law]
      settings_map[:city_for_disputes] = your_organization[:city_for_disputes]
    end

    settings_map.each do |name, value|
      SiteSetting::Update.call(
        guardian:,
        params: {
          setting_name: name,
          new_value: value,
        },
        options: {
          allow_changing_hidden: %i[
            extended_site_description
            extended_site_description_cooked
            about_banner_image
            community_owner
          ].include?(name),
        },
      )
    end
    render json: success_json
  end
end
