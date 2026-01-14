# frozen_string_literal: true

class SiteSetting::UpsertGroups
  include Service::Base

  params do
    before_validation { self.group_names = Array.wrap(self.group_names).delete_if(&:empty?) }

    attribute :group_names, :array
    attribute :setting, :string

    validates :setting, presence: true
  end

  policy :current_user_is_admin
  only_if(:provided_group_names) do
    model :group_ids

    transaction do
      step :upsert_site_setting_groups
      step :log_site_setting_groups_change
    end
  end
  only_if(:no_provided_group_names) do
    transaction do
      step :delete_site_setting_group
      step :log_site_setting_groups_change
    end
  end
  step :notify_changed

  private

  def provided_group_names(params:)
    params.group_names.present?
  end

  def no_provided_group_names(params:)
    !provided_group_names(params:)
  end

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def fetch_group_ids(params:)
    Group.where(name: params.group_names).pluck(:id)
  end

  def upsert_site_setting_groups(params:, group_ids:, guardian:)
    context[:previous_value] = SiteSettingGroup.find_by(name: params.setting)&.group_ids
    context[:new_value] = group_ids.sort.join("|")

    SiteSettingGroup.upsert(
      { name: params.setting, group_ids: context[:new_value] },
      unique_by: :name,
    )
  end

  def delete_site_setting_group(params:, guardian:)
    previous_record = SiteSettingGroup.find_by(name: params.setting)
    context[:previous_value] = previous_record&.group_ids
    context[:new_value] = ""

    previous_record&.destroy!
  end

  def log_site_setting_groups_change(params:, guardian:, new_value:, previous_value:)
    StaffActionLogger.new(guardian.user).log_site_setting_groups_change(
      params.setting,
      previous_value,
      new_value,
    )
  end

  def notify_changed
    SiteSetting.refresh_site_setting_group_ids!
    SiteSetting.notify_changed!
  end
end
