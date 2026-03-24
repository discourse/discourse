# frozen_string_literal: true

class UpcomingChanges::List
  include Service::Base

  policy :current_user_is_admin
  model :upcoming_changes, optional: true
  step :load_upcoming_change_groups
  step :sort_changes
  step :update_last_visited

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
        setting.slice(
          :setting,
          :humanized_name,
          :description,
          :value,
          :upcoming_change,
          :plugin,
        ).merge(
          dependents: SiteSetting.type_supervisor.dependencies.dependents(setting[:setting].to_s),
        )
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
      enabled_for, setting_groups =
        UpcomingChanges.enabled_for_with_groups(
          setting[:setting],
          setting[:value],
          groups,
        ).values_at(:enabled_for, :setting_groups)

      setting[:upcoming_change][:enabled_for] = enabled_for
      setting[:groups] = setting_groups
    end
  end

  def sort_changes(upcoming_changes:)
    context[:upcoming_changes] = upcoming_changes.sort_by { |change| change[:setting] }
  end

  def update_last_visited(guardian:)
    return if guardian.user.is_system_user? || guardian.user.bot?

    guardian.user.custom_fields["last_visited_upcoming_changes_at"] = Time.current.iso8601
    guardian.user.save_custom_fields
  end
end
