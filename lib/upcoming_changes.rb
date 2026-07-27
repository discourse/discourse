# frozen_string_literal: true

module UpcomingChanges
  # Some upcoming changes make no sense to display to admins,
  # for example ones related to Horizon theme makes no sense to
  # display if Horizon is not installed or is disabled, a change
  # might modify how site behavior works if another setting is enabled,
  # and so on.
  #
  # Core can define any should_display_<upcoming_change_name>? method to control
  # whether an upcoming change should be displayed to admins. Plugins can use
  # Plugin::Instance#register_upcoming_change_conditional_display for their own
  # upcoming changes. If no conditional display rule is defined, the change will
  # always be displayed.
  #
  # A plugin-owned change is hidden, and never takes effect, while its owning
  # plugin is disabled -- unless it opts out with `requires_plugin_enabled: false`.
  # See .owning_plugin_enabled?
  #
  # Keep in mind this is called from UpcomingChanges::List service,
  # which loops over every change in an N1 depending on the filters admins
  # have selected, so caching may be appropriate at times.
  class ConditionalDisplay
    def self.should_display?(upcoming_change_name)
      upcoming_change_name = upcoming_change_name.to_sym

      return false if !UpcomingChanges.owning_plugin_configurable?(upcoming_change_name)
      return false if !UpcomingChanges.owning_plugin_enabled?(upcoming_change_name)

      if respond_to?("should_display_#{upcoming_change_name}?")
        return public_send("should_display_#{upcoming_change_name}?")
      end

      callbacks =
        DiscoursePluginRegistry.upcoming_change_conditional_display_callbacks.select do |callback|
          callback[:setting_name] == upcoming_change_name
        end

      callbacks.empty? || callbacks.all? { |callback| callback[:callback].call }
    end

    def self.should_display_enable_horizon_high_context_topic_cards?
      Themes::Action::HorizonHighContextTopicCardsToggled.should_display_upcoming_change?
    end

    # Only relevant on sites that currently allow uncategorized topics, and must
    # stay visible after being enabled (which disables that setting).
    def self.should_display_remove_and_replace_uncategorized?
      SiteSetting::Action::RemoveAndReplaceUncategorizedToggled.should_display_upcoming_change?
    end

    # Code login is a delivery variant of email login (see
    # EnableLocalLoginsViaCodeValidator), so the change is only actionable when
    # local logins via email are possible. Must stay visible once enabled so
    # admins can still find and disable it.
    def self.should_display_enable_local_logins_via_code?
      return true if UpcomingChanges.enabled?(:enable_local_logins_via_code)

      SiteSetting.enable_local_logins && SiteSetting.enable_local_logins_via_email &&
        !SiteSetting.enable_discourse_connect
    end
  end

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

  # Mostly used for testing, to allow stubbing the SiteSetting provider,
  # like for SiteSettingExtension spec. This is not ideal, but the SiteSettingExtension spec
  # is extremely gnarly.
  def self.settings_provider
    SiteSetting
  end

  def self.previous_status_value(status)
    status_value = statuses[status.to_sym]
    statuses.values.select { |value| value < status_value }.max || -100
  end

  def self.previous_status(status)
    statuses.keys.select { |key| statuses[key] < statuses[status.to_sym] }.last || :conceptual
  end

  def self.next_status(status)
    status = status&.to_sym
    status_value = statuses[status]

    return if status_value.nil?
    return if status_value < statuses[:experimental] || status_value >= statuses[:stable]

    statuses.keys.find { |key| statuses[key] > status_value }
  end

  def self.image_exists?(change_setting_name)
    File.exist?(File.join(Rails.public_path, image_path(change_setting_name)))
  end

  def self.image_path(change_setting_name)
    plugin_name = settings_provider.plugins[change_setting_name.to_sym]
    if plugin_name.present?
      File.join("plugins", plugin_name, "images", "upcoming_changes", "#{change_setting_name}.png")
    else
      File.join("images", "upcoming_changes", "#{change_setting_name}.png")
    end
  end

  def self.image_data(change_setting_name, include_file_path: false)
    width, height = nil, nil

    full_file_path = File.join(Rails.public_path, image_path(change_setting_name))

    File.open(full_file_path, "rb") do |file|
      image_info = FastImage.new(file)
      width, height = image_info.size
    end

    data = { url: "#{Discourse.base_url}/#{image_path(change_setting_name)}", width:, height: }

    data[:file_path] = full_file_path if include_file_path

    data
  end

  def self.change_metadata(change_setting_name)
    change_setting_name = change_setting_name.to_sym
    settings_provider.upcoming_change_metadata[change_setting_name] || {}
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

  def self.exists?(change_setting_name)
    change_metadata(change_setting_name.to_sym).present?
  end

  # An upcoming change owned by a plugin that is not configurable on this site,
  # is never available. It must not be displayed, notified about, or enabled.
  #
  # This is deliberately broader than the guard in SiteSettingExtension#setting,
  # which only forces a plugin's own enabled_site_setting to false. A change
  # gating a sub-feature of an unavailable plugin is equally unavailable.
  #
  # Core changes have no owning plugin and return early, so the common case
  # never reaches #configurable? and adds no cost to callers on hot paths like
  # .settings_hidden_while_enabled.
  def self.owning_plugin_configurable?(change_setting_name)
    plugin_name = settings_provider.plugins[change_setting_name.to_sym]
    return true if plugin_name.nil?
    Discourse.plugins_by_name[plugin_name]&.configurable? != false
  end

  # Whether a plugin-owned change is gated on the plugin being enabled.
  # By default: upcoming changes in plugins are neither displayed nor take effect.
  # A plugin change can opt OUT with `requires_plugin_enabled: false`.
  def self.requires_plugin_enabled?(change_setting_name)
    change_metadata(change_setting_name)[:requires_plugin_enabled] != false
  end

  def self.owning_plugin_enabled?(change_setting_name)
    change_setting_name = change_setting_name.to_sym
    return true if !requires_plugin_enabled?(change_setting_name)

    plugin_name = settings_provider.plugins[change_setting_name]
    return true if plugin_name.nil?

    plugin = Discourse.plugins_by_name[plugin_name]
    return true if plugin.nil?

    # Recursion guard: a change that is its own plugin's enabled_site_setting
    # must opt out with requires_plugin_enabled: false (enforced by the
    # integrity spec), but if that metadata is forgotten, plugin.enabled? below
    # would read the change setting, which resolves back through
    # UpcomingChanges.enabled? and recurses infinitely.
    return true if plugin.enabled_site_setting&.to_sym == change_setting_name

    plugin.enabled? != false
  end

  # We dynamically determine if an upcoming change is enabled
  # or disabled based on the current status of the change as well
  # as whether the admin has manually toggled the change.
  #
  # @param change_setting_name [Symbol] The name of the upcoming change
  # @return [Boolean]
  def self.enabled?(change_setting_name)
    change_setting_name = change_setting_name.to_sym

    if !exists?(change_setting_name)
      raise ArgumentError, "Unknown upcoming change: #{change_setting_name}"
    end

    # The owning plugin is not available on this site, so neither is the change.
    # This intentionally takes precedence over the :permanent status below, since
    # a permanent change to an unavailable plugin still cannot take effect.
    return false if !owning_plugin_configurable?(change_setting_name)

    # The owning plugin is disabled, so the change must not take effect either.
    # Without this guard an opted-in change would keep acting on the site after
    # its plugin is switched off -- its `hide_settings` stay hidden and its
    # default overrides stay applied -- while ConditionalDisplay (which also
    # checks this) hides the change from admins, leaving them no way to see
    # what is causing those effects. The stored opt-in is deliberately left
    # untouched, so the change resumes when the plugin is re-enabled.
    return false if !owning_plugin_enabled?(change_setting_name)

    # An admin has modified the setting and a value is stored
    # in the database, since the default for upcoming changes
    # is false.
    #
    # If the change is permanent though, the admin has no choice
    # in the matter.
    if settings_provider.setting_modified_from_default?(change_setting_name) &&
         UpcomingChanges.change_status(change_setting_name) != :permanent
      settings_provider.current[change_setting_name]

      # The change has reached the promotion status and is forcibly
      # enabled, admins can still disable it.
    elsif UpcomingChanges.meets_or_exceeds_status?(
          change_setting_name,
          settings_provider.promote_upcoming_changes_on_status.to_sym,
        ) || UpcomingChanges.change_status(change_setting_name) == :permanent
      true
    else
      # Otherwise use the default value, which for upcoming changes
      # is false.
      settings_provider.defaults[change_setting_name]
    end
  end

  # The `allow_enabled_for` metadata for an upcoming change, or nil if unset.
  # When nil, every "Enabled for" dropdown option is permitted. Otherwise it
  # is an array containing any subset of [:everyone, :staff, :specific_groups].
  def self.allow_enabled_for(change_setting_name)
    change_metadata(change_setting_name)[:allow_enabled_for]
  end

  # Whether a setting's `allow_enabled_for` permits a given dropdown target.
  # `:no_one` is always allowed. Returns true when the metadata is absent.
  def self.target_allowed?(change_setting_name, target)
    return true if target.to_sym == :no_one
    allow = allow_enabled_for(change_setting_name)
    return true if allow.nil?
    allow.include?(target.to_sym)
  end

  # True when the setting's `allow_enabled_for` permits any group-based target
  # (`:staff` or `:specific_groups`). When metadata is absent, groups are allowed.
  def self.groups_target_allowed?(change_setting_name)
    allow = allow_enabled_for(change_setting_name)
    return true if allow.nil?
    allow.include?(:staff) || allow.include?(:specific_groups)
  end

  def self.has_groups?(change_setting_name)
    group_ids_for(change_setting_name).present?
  end

  def self.group_ids_for(change_setting_name)
    change_setting_name = change_setting_name.to_sym
    settings_provider.site_setting_group_ids[change_setting_name].presence || []
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
    setting_enabled = UpcomingChanges.enabled?(change_setting_name)

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

    settings_provider.upcoming_change_site_settings.filter_map do |name|
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
        humanized_name: settings_provider.humanized_name(name),
        description: settings_provider.description(name),
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
    group_ids_for_setting = settings_provider.site_setting_group_ids[setting_name]
    setting_groups =
      upcoming_change_selected_groups.values_at(*group_ids_for_setting).join(
        ",",
      ) if group_ids_for_setting.present?

    enabled_for =
      if !setting_value
        "no_one"
      elsif setting_groups.blank?
        # When `allow_enabled_for` excludes `:everyone` and the change is enabled
        # without an admin-configured scope (typically because it was auto-promoted
        # past the promotion threshold) we surface the broadest allowed target as
        # the dropdown's selected value, since `"everyone"` is no longer a valid
        # option. Backend access (`enabled_for_user?`) is unchanged — until the
        # admin picks a scope, the change is still effectively on for everyone.
        allow = allow_enabled_for(setting_name)
        if allow.nil? || allow.include?(:everyone)
          "everyone"
        elsif allow.include?(:staff)
          # Have to do this because the staff auto group name is localized
          upcoming_change_selected_groups[Group::AUTO_GROUPS[:staff]]
        else
          "groups"
        end
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

  def self.clear_caches!
    Discourse.cache.delete(current_statuses_cache_key)
    Discourse.cache.delete(permanent_upcoming_changes_cache_key)
    DiscourseUpdates.clear_latest_new_feature_created_at_cache
  end

  def self.current_statuses_cache_key
    "upcoming_changes_current_statuses::#{Discourse.git_version}"
  end

  # This also only changes once per deploy, so we can cache to the git version
  # to save time in other places in the codebase when we have to figure out
  # when an upcoming change moved to its current status.
  #
  # This cache is automatically cleared when UpcomingChanges::Action::TrackStatusChanges
  # is called, since that adds new UpcomingChangeEvent records.
  def self.current_statuses
    Discourse
      .cache
      .fetch(current_statuses_cache_key) do
        results = DB.query(<<-SQL, status_changed: UpcomingChangeEvent.event_types[:status_changed])
          WITH latest_status_changes AS (
            SELECT upcoming_change_name, MAX(created_at) as created_at
            FROM upcoming_change_events
            WHERE event_type = :status_changed
            GROUP BY upcoming_change_name
            ORDER BY MAX(created_at) DESC
          )
          SELECT latest_status_changes.upcoming_change_name, latest_status_changes.created_at, upcoming_change_events.event_data->>'new_value' as new_value
          FROM latest_status_changes
          INNER JOIN upcoming_change_events ON upcoming_change_events.upcoming_change_name = latest_status_changes.upcoming_change_name AND upcoming_change_events.created_at = latest_status_changes.created_at
          ORDER BY latest_status_changes.created_at DESC
        SQL

        results.each_with_object({}) do |result, statuses|
          statuses[result.upcoming_change_name] = {
            status: result.new_value,
            changed_at: result.created_at,
          }
        end
      end
  end

  def self.permanent_upcoming_changes_cache_key
    "upcoming_changes_permanent::#{Discourse.git_version}"
  end

  # These don't change except on deploy, so we can cache to the git version
  # to save time in other places in the codebase when we have to figure out
  # whether a change is permanent or not.
  def self.permanent_upcoming_changes
    Discourse
      .cache
      .fetch(permanent_upcoming_changes_cache_key) do
        result =
          UpcomingChanges::List.call(
            guardian: Discourse.system_user.guardian,
            options: {
              filter_statuses: [:permanent],
            },
          )

        if !result.success? && Rails.env.local?
          puts result.inspect_steps
          raise
        end

        result.upcoming_changes
      end
  end

  # The setting names of all permanent upcoming changes. Used on the frontend
  # to decide whether a notification should link to the upcoming changes page
  # or to the What's New page (where permanent changes are surfaced).
  def self.permanent_upcoming_change_names
    permanent_upcoming_changes.map { |uc| uc[:setting].to_s }
  end

  # No point in notifying admins on brand new sites, the upcoming change system
  # is more about notifying admins of changes to established sites.
  #
  # Of course we don't care about this in development, we need to test notifications,
  # and we can stub this method in rspec.
  def self.should_notify_admins?
    Migration::Helpers.existing_site? || Rails.env.development?
  end

  # Some upcoming changes have a depends_on relationship with other settings,
  # where it doesn't make sense to show the dependent settings in the site
  # settings UI unless the upcoming change is enabled.
  #
  # This is done via depends_on and depends_behavior: hidden in site_settings.yml.
  def self.find_dependents_for_change(change_setting_name)
    settings_provider.type_supervisor.dependencies.dependents(change_setting_name.to_s)
  end

  # Whether the settings the change itself depends_on (in site_settings.yml)
  # currently hold the values the change needs. Used by the admin UI to warn
  # admins when a change's prerequisites are not met, since enabling the change
  # would have no effect (or be rejected by a validator) until they are.
  def self.change_dependencies_met?(change_setting_name)
    dependencies = settings_provider.type_supervisor.dependencies[change_setting_name.to_sym]
    return true if dependencies.blank?

    allowed_values = settings_provider.dependency_values[change_setting_name.to_sym]
    dependencies.all? do |dependency|
      value = settings_provider.public_send(dependency)
      if (allowed = allowed_values&.dig(dependency))
        allowed.include?(value.to_s)
      else
        value == true
      end
    end
  end

  def self.including_css
    settings_provider.upcoming_change_site_settings.filter_map do |upcoming_change|
      upcoming_change if settings_provider.upcoming_change_metadata[upcoming_change][:body_class]
    end
  end

  # Site settings to hide from admins because an upcoming change that declares
  # `hide_settings:` (in its site_settings.yml metadata) is currently enabled.
  # Legacy settings a change replaces stop making sense once the change is in
  # effect, so they are hidden while it is enabled.
  #
  # Consulted by SiteSettings::HiddenProvider#all, which runs on every
  # hidden_settings read. It is computed live rather than toggled at opt-in time
  # so it tracks both opt-in paths (manual and auto-promotion) and is
  # multisite-safe: the hidden set is process-global, but enabled? resolves
  # per-site, so we never hide a setting for sites that haven't opted in.
  #
  # `enabled?` is only called for the (usually zero) changes that declare
  # `hide_settings`, so the common case is a cheap metadata scan with no DB hit.
  def self.settings_hidden_while_enabled
    metadata = settings_provider.upcoming_change_metadata
    return [] if metadata.empty?

    metadata.each_with_object([]) do |(change_name, change_metadata), hidden|
      next if change_metadata[:hide_settings].blank?
      hidden.concat(change_metadata[:hide_settings]) if enabled?(change_name)
    end
  end
end
