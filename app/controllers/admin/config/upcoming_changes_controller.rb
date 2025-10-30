# frozen_string_literal: true
#
class Admin::Config::UpcomingChangesController < Admin::AdminController
  def index
    return if !request.xhr?

    UpcomingChanges::List.call(service_params) do
      on_success { |upcoming_changes:| render(json: upcoming_changes) }
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
    end
  end

  def update_groups
    SiteSetting::UpsertGroups.call(service_params) do |result|
      on_success { render(json: success_json) }
      on_model_not_found(:group_ids) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
    end
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
