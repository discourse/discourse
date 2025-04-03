# frozen_string_literal: true

class SiteSetting::Policy::ValuesAreValid < Service::PolicyBase
  delegate :options, :params, to: :context

  def call
    @setting_errors = params.settings.filter_map(&method(:validate_setting))
    @setting_errors.empty?
  end

  def reason
    @setting_errors.join(", ")
  end

  private

  def validate_setting(setting)
    setting_type = SiteSetting.type_supervisor.get_type(setting.name)
    begin
      SiteSetting.type_supervisor.validate_value(setting.name, setting_type, setting.value)
      nil
    rescue Discourse::InvalidParameters => e
      e.message
    end
  end
end
