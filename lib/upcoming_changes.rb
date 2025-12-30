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
      ::Enum.new(experimental: 0, alpha: 100, beta: 200, stable: 300, permanent: 500, never: 9999)
  end

  def self.image_exists?(change_setting_name)
    File.exist?(File.join(Rails.public_path, self.image_path(change_setting_name)))
  end

  def self.image_path(change_setting_name)
    File.join("images", "upcoming_changes", "#{change_setting_name}.png")
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
end
