# frozen_string_literal: true

# TODO (martin) Test all of this class
module UpcomingChanges
  def self.statuses
    @statuses ||= Enum.new(pre_alpha: 0, alpha: 100, beta: 200, stable: 300, permanent: 500)
  end

  def self.image_exists?(change_setting_name)
    File.exist?(self.image_path(change_setting_name))
  end

  def self.image_path(change_setting_name)
    Rails.public_path.join("public", "images", "upcoming_changes", "#{change_setting_name}.png")
  end

  def self.change_metadata(change_setting_name)
    SiteSetting.upcoming_change_metadata[change_setting_name.to_sym] || {}
  end

  def self.not_yet_stable?(change_setting_name)
    change_status_value(change_setting_name) < UpcomingChanges.statuses[:stable]
  end

  def self.stable_or_permanent?(change_setting_name)
    change_status_value(change_setting_name) >= UpcomingChanges.statuses[:stable]
  end

  def self.change_status_value(change_setting_name)
    UpcomingChanges.statuses[change_metadata(change_setting_name)[:status]]
  end

  def self.history_for(change_setting_name)
    UserHistory.where(
      action: UserHistory.actions[:upcoming_change_toggled],
      subject: change_setting_name,
    ).order(created_at: :desc)
  end
end
