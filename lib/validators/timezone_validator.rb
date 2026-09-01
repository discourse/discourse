# frozen_string_literal: true

class TimezoneValidator < ActiveModel::EachValidator
  class << self
    def valid?(value)
      ok = ActiveSupport::TimeZone[value].present?
      Rails.logger.warn("Invalid timezone '#{value}' detected!") if !ok
      ok
    end

    def error_message(value)
      I18n.t("errors.messages.invalid_timezone", tz: value)
    end
  end

  def validate_each(record, attribute, value)
    return if value.blank? || TimezoneValidator.valid?(value)
    record.errors.add(attribute, :timezone, message: TimezoneValidator.error_message(value))
  end
end
