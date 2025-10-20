# frozen_string_literal: true
# TODO (martin) Add controller tests
class Admin::Config::UpcomingChangesController < Admin::AdminController
  def index
    if request.xhr?
      UpcomingChanges::List.call(guardian: current_user.guardian) do
        on_success { |upcoming_changes:| render(json: upcoming_changes) }
        on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      end
    end
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
    UpcomingChanges::Toggle.call(service_params) do
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
