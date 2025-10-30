# frozen_string_literal: true

module UpcomingChanges
  def self.statuses
    @statuses ||= Enum.new(pre_alpha: 0, alpha: 100, beta: 200, stable: 300, permanent: 500)
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
    SiteSetting.upcoming_change_metadata[change_setting_name.to_sym] || {}
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
    UserHistory.where(
      action: UserHistory.actions[:upcoming_change_toggled],
      subject: change_setting_name,
    ).order(created_at: :desc)
  end

  def self.has_groups?(change_setting_name)
    group_ids_for(change_setting_name).present?
  end

  def self.group_ids_for(change_setting_name)
    SiteSetting.site_setting_group_ids[change_setting_name].presence || []
  end
end
