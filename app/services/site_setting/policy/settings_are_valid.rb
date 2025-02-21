# frozen_string_literal: true

class SiteSetting::Policy::SettingsAreValid < Service::PolicyBase
  delegate :options, to: :context
  delegate :params, to: :context

  def call
    @setting_errors =
      params
        .settings
        .to_a
        .map do |setting_name, setting_value|
          type = SiteSetting.type_supervisor.get_type(setting_name)
          begin
            SiteSetting.type_supervisor.validate_value(setting_name, type, setting_value)
            nil
          rescue Discourse::InvalidParameters => e
            e.message
          end
        end
        .compact
    @setting_errors.empty?
  end

  def reason
    @setting_errors.join(", ")
  end
end
