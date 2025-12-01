# frozen_string_literal: true

class TopicSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    val.blank? || Topic.with_deleted.exists?(id: val)
  end

  def error_message
    I18n.t("site_settings.errors.invalid_topic")
  end
end
