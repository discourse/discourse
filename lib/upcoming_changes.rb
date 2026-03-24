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

  # We dynamically determine if an upcoming change is enabled
  # or disabled based on the current status of the change as well
  # as whether the admin has manually toggled the change.
  #
  # @param change_setting_name [Symbol] The name of the upcoming change
  # @return [Boolean]
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

  # Returns the effective default for a target setting that has an
  # upcoming_change_default_override, or nil if the override is not active.
  # When the linked upcoming change is enabled (via resolved_value), the
  # target setting's default shifts to the override value.
  #
  # @param target_setting_name [Symbol] The name of the target setting
  # @return [Object, nil] The override default value, or nil if not active
  def self.effective_default_for(target_setting_name)
    override = SiteSetting.upcoming_change_default_overrides[target_setting_name.to_sym]
    return nil unless override || SiteSetting.upcoming_change_metadata.key?(override[:setting])

    # If upcoming change is enabled, then use the new default override
    resolved_value(override[:setting]) ? override[:default] : nil
  end

  def self.has_groups?(change_setting_name)
    group_ids_for(change_setting_name).present?
  end

  def self.group_ids_for(change_setting_name)
    change_setting_name = change_setting_name.to_sym
    SiteSetting.site_setting_group_ids[change_setting_name].presence || []
  end

  # Checks if a given upcoming change is enabled for a user,
  # which can be either enabled for everyone, enabled for certain groups,
  # or disabled for everyone. The user's group membership is used to determine
  # if the upcoming change is enabled for them if the upcoming change is
  # enabled for certain groups.
  #
  # @param change_setting_name [Symbol] The name of the upcoming change
  # @param user [User] The user to check if the upcoming change is enabled for
  # @return [Boolean]
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

  # Calculates the current state of all upcoming changes for a given user,
  # including the reason why a change is or isn't enabled for them, and
  # if it's due to group membership, which groups are relevant.
  #
  # The acting_guardian is used to determine group visibility. This is
  # mostly used to show a list of upcoming changes for a user in the admin
  # interface.
  #
  # @param user [User] The user to get the upcoming changes for
  # @param acting_guardian [Guardian] The current user's guardian
  # @return [Array<Hash>]
  #
  # @example
  #   stats_for_user(user: user, acting_guardian: admin)
  #   # => [
  #   #   {
  #   #     name: "new_feature",
  #   #     humanized_name: "New Feature",
  #   #     description: "This is a new feature",
  #   #     enabled: true,
  #   #     specific_groups: ["Group 1", "Group 2"],
  #   #     reason: :in_specific_groups
  #   #   },
  #   #   {
  #   #     name: "another_feature",
  #   #     humanized_name: "Another Feature",
  #   #     description: "This is another feature",
  #   #     enabled: false,
  #   #     specific_groups: [],
  #   #     reason: :enabled_for_no_one
  #   #   },
  #   # ]
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

  # For a given setting, we need to determine the enabled for value
  # for the UI based on the setting value, and if the setting is enabled
  # for certain groups, we need the actual group records to display in the UI.
  # Mostly a utility method.
  #
  # @param setting_name [Symbol] The name of the setting
  # @param setting_value [Boolean] The value of the setting
  # @param upcoming_change_selected_groups [Hash] A hash of group ids to group names
  #   across all upcoming changes.
  # @return [Hash] The enabled for value and the setting groups
  #
  # @example
  #   enabled_for_with_groups(:new_feature, true, { 1 => "Group 1", 2 => "Group 2" })
  def self.enabled_for_with_groups(setting_name, setting_value, upcoming_change_selected_groups)
    group_ids_for_setting = SiteSetting.site_setting_group_ids[setting_name]
    setting_groups =
      upcoming_change_selected_groups.values_at(*group_ids_for_setting).join(
        ",",
      ) if group_ids_for_setting.present?

    enabled_for =
      if !setting_value
        "no_one"
      elsif setting_groups.blank?
        "everyone"
      else
        if group_ids_for_setting == [Group::AUTO_GROUPS[:staff]]
          # Have to do this because the staff auto group name is localized
          upcoming_change_selected_groups[Group::AUTO_GROUPS[:staff]]
        else
          "groups"
        end
      end

    { enabled_for:, setting_groups: }
  end
end
