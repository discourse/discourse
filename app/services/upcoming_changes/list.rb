# frozen_string_literal: true

class UpcomingChanges::List
  include Service::Base

  policy :current_user_is_admin
  model :upcoming_changes, optional: true
  step :load_upcoming_change_groups
  step :sort_changes

  private

  def current_user_is_admin(guardian:)
    guardian.is_admin?
  end

  def fetch_upcoming_changes
    SiteSetting
      .all_settings(
        only_upcoming_changes: true,
        include_hidden: true,
        include_locale_setting: false,
      )
      .each do |setting|
        setting[:value] = setting[:value] == "true"

        if UpcomingChanges.image_exists?(setting[:setting])
          setting[:upcoming_change][:image] = UpcomingChanges.image_data(setting[:setting])
        end

        if setting[:plugin]
          plugin = Discourse.plugins_by_name[setting[:plugin]]

          # NOTE (martin) Maybe later we add a URL or something? Not sure.
          # Then the plugin name could be clicked in the UI
          setting[:plugin] = plugin.humanized_name
        end
      end
      .map do |setting|
        # We don't need to return all the other setting metadata for
        # endpoints that use this.
        setting.slice(:setting, :humanized_name, :description, :value, :upcoming_change, :plugin)
      end
  end

  def load_upcoming_change_groups(upcoming_changes:)
    group_ids =
      upcoming_changes
        .map { |change| SiteSetting.site_setting_group_ids[change[:setting]] }
        .flatten
        .compact
        .uniq

    groups = Group.where(id: group_ids).pluck(:id, :name).to_h

    upcoming_changes.each do |setting|
      group_ids_for_setting = SiteSetting.site_setting_group_ids[setting[:setting]]
      setting[:groups] = groups.values_at(*group_ids_for_setting).join(
        ",",
      ) if group_ids_for_setting.present?

      setting[:upcoming_change][:enabled_for] = if !setting[:value]
        "no_one"
      elsif setting[:groups].blank?
        "everyone"
      else
        if group_ids_for_setting == [Group::AUTO_GROUPS[:staff]]
          "staff"
        else
          "groups"
        end
      end
    end
  end

  def sort_changes(upcoming_changes:)
    context[:upcoming_changes] = upcoming_changes.sort_by { |change| change[:setting] }
  end
end
