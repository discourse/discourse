# frozen_string_literal: true

module UpcomingChanges
  def self.statuses
    @statuses ||= Enum.new(pre_alpha: 0, alpha: 100, beta: 200, stable: 300, permanent: 500)
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
end
