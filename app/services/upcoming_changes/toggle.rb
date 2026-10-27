# frozen_string_literal: true

class UpcomingChanges::Toggle
  include Service::Base

  # For cases like the UpcomingChanges::Promote where we don't want to log
  # the change again since it's already being logged there.
  options { attribute :log_change, default: true }

  params do
    attribute :setting_name, :symbol
    attribute :enabled, :boolean
    attribute :group_names, :array

    before_validation do
      self.group_names =
        UpcomingChanges.normalize_group_names(setting_name, group_names) if setting_name.present? &&
        !group_names.nil?
    end

    validates :setting_name, presence: true
    validates :enabled, inclusion: [true, false]

    def upcoming_change_event
      enabled ? :upcoming_change_enabled : :upcoming_change_disabled
    end
  end

  policy :current_user_is_admin
  policy :setting_is_available
  policy :allowed_enabled_for_target
  only_if(:updating_groups) { model :group_ids, optional: true }

  transaction do
    only_if(:updating_groups) do
      step :update_groups
      step :log_groups_change
    end
    step :toggle
  end

  step :clear_groups_if_groups_not_allowed
  only_if(:updating_groups) { step :notify_groups_changed }

  only_if(:should_log_change) do
    step :log_change
    step :log_event
  end

  step :trigger_event

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def setting_is_available(params:)
    UpcomingChanges.exists?(params.setting_name)
  end

  def toggle(params:, guardian:, options:)
    context[:previous_value] = SiteSetting.public_send(params.setting_name)
    SiteSetting.send("#{params.setting_name}=", params.enabled)
  end

  def allowed_enabled_for_target(params:)
    names = params.group_names
    if names.nil?
      return true if !params.enabled
      names =
        if UpcomingChanges.groups_target_allowed?(params.setting_name)
          Group.where(id: UpcomingChanges.group_ids_for(params.setting_name)).pluck(:name)
        else
          []
        end
    end
    if names.empty? && !params.enabled
      return(
        UpcomingChanges.allow_enabled_for(params.setting_name)&.sort != %i[specific_groups staff]
      )
    end

    UpcomingChanges.group_scope_allowed?(params.setting_name, names)
  end

  def updating_groups(params:)
    !params.group_names.nil?
  end

  def fetch_group_ids(params:)
    ids = Group.where(name: params.group_names).pluck(:id)
    raise Discourse::NotFound if ids.length != params.group_names.length
    ids
  end

  def update_groups(params:, group_ids:)
    context[:previous_groups] = SiteSettingGroup.find_by(name: params.setting_name)&.group_ids
    context[:new_groups] = group_ids.sort.join("|")
    if group_ids.empty?
      SiteSettingGroup.where(name: params.setting_name).delete_all
    else
      SiteSettingGroup.upsert(
        { name: params.setting_name, group_ids: context[:new_groups] },
        unique_by: :name,
      )
    end
  end

  def log_groups_change(params:, guardian:, previous_groups:, new_groups:)
    StaffActionLogger.new(guardian.user).log_site_setting_groups_change(
      params.setting_name,
      previous_groups,
      new_groups,
    )
  end

  def clear_groups_if_groups_not_allowed(params:)
    return if UpcomingChanges.groups_target_allowed?(params.setting_name)

    SiteSettingGroup.find_by(name: params.setting_name)&.destroy!
    SiteSetting.refresh_site_setting_group_ids!
  end

  def notify_groups_changed
    SiteSetting.refresh_site_setting_group_ids!
    SiteSetting.notify_changed!
  end

  def should_log_change(options:)
    options.log_change
  end

  def log_change(params:, guardian:, options:)
    StaffActionLogger.new(guardian.user).log_upcoming_change_toggle(
      params.setting_name,
      context[:previous_value],
      params.enabled,
      { context: I18n.t("staff_action_logs.upcoming_changes.log_manually_toggled") },
    )
  end

  def log_event(params:, guardian:, options:)
    UpcomingChangeEvent.create!(
      event_type: params.enabled ? :manual_opt_in : :manual_opt_out,
      upcoming_change_name: params.setting_name,
      acting_user: guardian.user,
    )
  end

  def trigger_event(params:)
    DiscourseEvent.trigger(params.upcoming_change_event, params.setting_name)
  end
end
