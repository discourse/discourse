# frozen_string_literal: true

module UpcomingChanges
  def self.user_enabled_reasons
    @user_enabled_reasons ||=
      ::Enum.new(
        enabled_for_everyone: :enabled_for_everyone,
        enabled_for_no_one: :enabled_for_no_one,
        in_specific_groups: :in_specific_groups,
        not_in_specific_groups: :not_in_specific_groups,
      )
  end

  def self.statuses
    @statuses ||=
      ::Enum.new(
        conceptual: -100,
        experimental: 0,
        alpha: 100,
        beta: 200,
        stable: 300,
        permanent: 500,
        never: 9999,
      )
  end

  def self.previous_status_value(status)
    status_value = self.statuses[status.to_sym]
    self.statuses.values.select { |value| value < status_value }.max || -100
  end

  def self.previous_status(status)
    self.statuses.keys.select { |key| self.statuses[key] < self.statuses[status.to_sym] }.last ||
      :conceptual
  end

  def self.image_exists?(change_setting_name)
    File.exist?(File.join(Rails.public_path, self.image_path(change_setting_name)))
  end

  def self.image_path(change_setting_name)
    plugin_name = SiteSetting.plugins[change_setting_name.to_sym]
    if plugin_name.present?
      File.join("plugins", plugin_name, "images", "upcoming_changes", "#{change_setting_name}.png")
    else
      File.join("images", "upcoming_changes", "#{change_setting_name}.png")
    end
  end

  def self.image_data(change_setting_name)
    width, height = nil, nil

    File.open(File.join(Rails.public_path, image_path(change_setting_name)), "rb") do |file|
      image_info = FastImage.new(file)
      width, height = image_info.size
    end

    { url: "#{Discourse.base_url}/#{image_path(change_setting_name)}", width:, height: }
  end

  def self.change_metadata(change_setting_name)
    change_setting_name = change_setting_name.to_sym
    SiteSetting.upcoming_change_metadata[change_setting_name] || {}
  end

  def self.not_yet_stable?(change_setting_name)
    change_status_value(change_setting_name) < UpcomingChanges.statuses[:stable]
  end

  def self.stable_or_permanent?(change_setting_name)
    change_status_value(change_setting_name) >= UpcomingChanges.statuses[:stable]
  end

  def self.meets_or_exceeds_status?(change_setting_name, status)
    change_status_value(change_setting_name) >= UpcomingChanges.statuses[status]
  end

  def self.change_status_value(change_setting_name)
    UpcomingChanges.statuses[change_status(change_setting_name)]
  end

  def self.change_status(change_setting_name)
    change_metadata(change_setting_name)[:status]
  end

  def self.history_for(change_setting_name)
    change_setting_name = change_setting_name.to_sym
    UserHistory.where(
      action: UserHistory.actions[:upcoming_change_toggled],
      subject: change_setting_name,
    ).order(created_at: :desc)
  end

  def self.resolved_value(change_setting_name)
    # An admin has modified the setting and a value is stored
    # in the database, since the default for upcoming changes
    # is false.
    #
    # If the change is permanent though, the admin has no choice
    # in the matter.
    if SiteSetting.modified.key?(change_setting_name) &&
         UpcomingChanges.change_status(change_setting_name) != :permanent
      SiteSetting.current[change_setting_name]

      # The change has reached the promotion status and is forcibly
      # enabled, admins can still disable it.
    elsif UpcomingChanges.meets_or_exceeds_status?(
          change_setting_name,
          SiteSetting.promote_upcoming_changes_on_status.to_sym,
        ) || UpcomingChanges.change_status(change_setting_name) == :permanent
      true
    else
      # Otherwise use the default value, which for upcoming changes
      # is false.
      SiteSetting.defaults[change_setting_name]
    end
  end

  def self.has_groups?(change_setting_name)
    group_ids_for(change_setting_name).present?
  end

  def self.group_ids_for(change_setting_name)
    change_setting_name = change_setting_name.to_sym
    SiteSetting.site_setting_group_ids[change_setting_name].presence || []
  end

  def self.enabled_for_user?(change_setting_name, user)
    change_setting_name = change_setting_name.to_sym
    setting_enabled = SiteSetting.public_send(change_setting_name)

    # Anon users can only have upcoming changes enabled if it's set for Everyone
    if user.blank?
      return false if UpcomingChanges.has_groups?(change_setting_name)
    else
      if UpcomingChanges.has_groups?(change_setting_name)
        return(
          setting_enabled && user.in_any_groups?(UpcomingChanges.group_ids_for(change_setting_name))
        )
      end
    end

    setting_enabled
  end

  def self.stats_for_user(user:, acting_guardian:)
    guardian_visible_group_ids = Group.visible_groups(acting_guardian.user).pluck(:id)
    user_belonging_to_group_ids = user.belonging_to_group_ids

    SiteSetting.upcoming_change_site_settings.filter_map do |name|
      next if UpcomingChanges.change_status(name) == :conceptual
      enabled = user.upcoming_change_enabled?(name)
      has_groups = UpcomingChanges.has_groups?(name)

      specific_groups = []
      reason =
        if has_groups
          visible_group_ids =
            UpcomingChanges.group_ids_for(name) & guardian_visible_group_ids &
              user_belonging_to_group_ids

          specific_groups = Group.where(id: visible_group_ids).pluck(:name)
          if enabled
            UpcomingChanges.user_enabled_reasons[:in_specific_groups]
          else
            UpcomingChanges.user_enabled_reasons[:not_in_specific_groups]
          end
        elsif enabled
          UpcomingChanges.user_enabled_reasons[:enabled_for_everyone]
        else
          UpcomingChanges.user_enabled_reasons[:enabled_for_no_one]
        end

      {
        name:,
        humanized_name: SiteSetting.humanized_name(name),
        description: SiteSetting.description(name),
        enabled:,
        specific_groups:,
        reason:,
      }
    end
  end
end
