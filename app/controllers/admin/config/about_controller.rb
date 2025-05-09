# frozen_string_literal: true

class Admin::Config::AboutController < Admin::AdminController
  def index
  end

  def update
    settings = []

    if general_settings = params[:general_settings]
      settings << { setting_name: "title", value: general_settings[:name] }
      settings << { setting_name: "site_description", value: general_settings[:summary] }
      settings << {
        setting_name: "about_banner_image",
        value: general_settings[:about_banner_image],
      }

      settings << {
        setting_name: "extended_site_description",
        value: general_settings[:extended_description],
      }
      settings << {
        setting_name: "short_site_description",
        value: general_settings[:community_title],
      }

      if general_settings[:extended_description].present?
        settings << {
          setting_name: "extended_site_description_cooked",
          value: PrettyText.markdown(general_settings[:extended_description]),
        }
      else
        settings << { setting_name: "extended_site_description_cooked", value: "" }
      end
    end

    if contact_information = params[:contact_information]
      settings << { setting_name: "community_owner", value: contact_information[:community_owner] }
      settings << { setting_name: "contact_email", value: contact_information[:contact_email] }
      settings << { setting_name: "contact_url", value: contact_information[:contact_url] }
      settings << {
        setting_name: "site_contact_username",
        value: contact_information[:contact_username],
      }
      settings << {
        setting_name: "site_contact_group_name",
        value: contact_information[:contact_group_name],
      }
    end

    if your_organization = params[:your_organization]
      settings << { setting_name: "company_name", value: your_organization[:company_name] }
      settings << { setting_name: "governing_law", value: your_organization[:governing_law] }
      settings << {
        setting_name: "city_for_disputes",
        value: your_organization[:city_for_disputes],
      }
    end

    if extra_groups = params[:extra_groups]
      settings << { setting_name: "about_page_extra_groups", value: extra_groups[:groups] }
      settings << {
        setting_name: "about_page_extra_groups_initial_members",
        value: extra_groups[:initial_members],
      }
      settings << { setting_name: "about_page_extra_groups_order", value: extra_groups[:order] }
      settings << {
        setting_name: "about_page_extra_groups_show_description",
        value: extra_groups[:show_description],
      }
    end

    SiteSetting::Update.call(
      guardian:,
      params: {
        settings:,
      },
      options: {
        allow_changing_hidden: %i[
          extended_site_description
          extended_site_description_cooked
          about_banner_image
          community_owner
        ],
      },
    ) do
      on_success { render json: success_json }
      on_failed_policy(:settings_are_not_deprecated) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:settings_are_visible) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:settings_are_unshadowed_globally) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:settings_are_configurable) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
      on_failed_policy(:values_are_valid) do |policy|
        raise Discourse::InvalidParameters, policy.reason
      end
    end
  end
end
