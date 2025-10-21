# frozen_string_literal: true

class SiteSetting::UpsertGroups
  include Service::Base

  params do
    attribute :group_names, :array
    attribute :setting, :string

    validates :group_names, presence: true
    validates :setting, presence: true
  end

  policy :current_user_is_admin
  model :group_ids
  step :upsert_site_setting_groups

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def fetch_group_ids(params:)
    Group.where(name: params.group_names).pluck(:id)
  end

  def upsert_site_setting_groups(params:, group_ids:, guardian:)
    previous_value = SiteSettingGroup.find_by(name: params.setting)&.group_ids
    joined_group_ids = group_ids.join("|")

    ActiveRecord::Base.transaction do
      SiteSettingGroup.upsert(
        { name: params.setting, group_ids: joined_group_ids },
        unique_by: :name,
      )
      StaffActionLogger.new(guardian.user).log_site_setting_groups_change(
        params.setting,
        previous_value,
        joined_group_ids,
      )
    end

    SiteSetting.notify_changed!
  end
end
