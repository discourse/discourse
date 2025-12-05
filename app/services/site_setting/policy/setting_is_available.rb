# frozen_string_literal: true

class SiteSetting::Policy::SettingIsAvailable < Service::PolicyBase
  delegate :options, :params, to: :context

  def call
    SiteSetting.respond_to?(params.setting_name)
  end

  def reason
  end
end
