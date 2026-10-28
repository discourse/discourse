# frozen_string_literal: true

class UpcomingChanges::UpdateGroups
  include Service::Base

  params do
    attribute :setting, :string
    attribute :group_names, :array

    before_validation { self.group_names = Array.wrap(group_names).reject(&:blank?).uniq }

    validates :setting, :group_names, presence: true
  end

  policy :current_user_is_admin
  policy :setting_is_available
  model :group_setting
  model :group_ids
  policy :groups_are_allowed
  step :update_setting
  model :groups, :fetch_saved_groups

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def setting_is_available(params:)
    UpcomingChanges.exists?(params.setting)
  end

  def fetch_group_setting(params:)
    UpcomingChanges.group_setting_data(params.setting)
  end

  def fetch_group_ids(params:)
    ids = Group.where(name: params.group_names).pluck(:id)
    ids if ids.length == params.group_names.length
  end

  def groups_are_allowed(group_setting:, group_ids:)
    (group_ids & group_setting[:disallowed_groups].to_s.split("|").map(&:to_i)).empty?
  end

  def update_setting(guardian:, group_setting:, group_ids:)
    error = nil
    SiteSetting::Update.call(
      guardian:,
      params: {
        settings: [{ setting_name: group_setting[:setting], value: group_ids.join("|") }],
      },
    ) do |result|
      on_failure { error = I18n.t("invalid_params", message: group_setting[:setting]) }
      on_exceptions { |exception| error = exception.message }
      on_failed_policy(:settings_are_not_deprecated) { |policy| error = policy.reason }
      on_failed_policy(:settings_are_visible) { |policy| error = policy.reason }
      on_failed_policy(:settings_are_unshadowed_globally) { |policy| error = policy.reason }
      on_failed_policy(:settings_are_configurable) { |policy| error = policy.reason }
    end
    fail!(error) if error
  end

  def fetch_saved_groups(params:)
    Group.where(id: UpcomingChanges.group_ids_for(params.setting)).order(:id).pluck(:name).join(",")
  end
end
