# frozen_string_literal: true
#
class Admin::Config::UpcomingChangesController < Admin::AdminController
  def index
    return if !request.xhr?

    filter_statuses = params[:filter_statuses]&.split(",") || []

    UpcomingChanges::List.call(service_params.merge(options: { filter_statuses: })) do
      on_success { |upcoming_changes:| render(json: upcoming_changes) }
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
    end
  end

  def update_groups
    if UpcomingChanges.group_setting_name(params[:setting].to_s)
      UpcomingChanges::UpdateGroups.call(service_params) do
        on_success do |groups:, group_setting:|
          render(json: success_json.merge(groups:, group_setting:))
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
        on_model_not_found(:group_setting) { raise Discourse::NotFound }
        on_model_not_found(:group_ids) { raise Discourse::NotFound }
        on_failed_step(:update_setting) do |step|
          render(json: failed_json.merge(errors: [step.error]), status: :unprocessable_entity)
        end
      end

      return
    end

    SiteSetting::UpsertGroups.call(service_params) do |result|
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
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
      on_failed_policy(:setting_is_available) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end
end
