# frozen_string_literal: true
class Admin::Config::UpcomingChangesController < Admin::AdminController
  def index
    # TODO (martin) Move this into a service
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

                   # TODO (martin) Maybe later we add a URL or something? Not sure.
                   # Then the plugin name could be clicked in the UI
                   setting[:plugin] = plugin.humanized_name
                 end

                 if SiteSetting.site_setting_group_ids.key?(setting[:setting]) &&
                      SiteSetting.site_setting_group_ids[setting[:setting]].present?
                   setting[:groups] = Group.where(
                     id: SiteSetting.site_setting_group_ids[setting[:setting]],
                   ).pluck(:name)
                 end
               }
               .sort_by { |s| s[:setting] } if request.xhr?
  end

  # TODO (martin) Move this into a service
  def update_groups
    setting = params.require(:setting)
    groups = params.require(:groups)

    group_ids = Group.where(name: groups).pluck(:id).join("|")

    SiteSettingGroup.upsert({ name: setting, group_ids: group_ids }, unique_by: :name)

    # SiteSetting.site_setting_group_ids[setting] = group_ids
    SiteSetting.notify_changed!

    render json: success_json
  end

  def toggle_change
    # TODO (martin) Change this to UpcomingChange::Toggle
    Experiments::Toggle.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_failed_policy(:setting_is_available) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end
end
