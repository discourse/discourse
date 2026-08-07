# frozen_string_literal: true

class CalendarCustomFieldsValidator
  NAME_FORMAT = /\A[a-z0-9]+([_.-][a-z0-9]+)*\z/i

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    @error_message = nil
    return true if val.blank?

    names = val.split("|").reject(&:blank?)
    attributes =
      names.index_with { |name| DiscoursePostEvent::EventParser.custom_field_data_attribute(name) }
    errors = []

    malformed = names.reject { |name| name.match?(NAME_FORMAT) }
    errors << error(:invalid, malformed) if malformed.any?

    colliding =
      names.group_by { |name| attributes[name] }.values.select { |group| group.size > 1 }.flatten
    errors << error(:collision, colliding) if colliding.any?

    reserved = DiscoursePostEvent::EventParser.valid_option_attributes
    reserved_names = names.select { |name| reserved.include?(attributes[name]) }
    errors << error(:reserved, reserved_names) if reserved_names.any?

    return true if errors.empty?

    @error_message = errors.join(" ")
    false
  end

  def error_message
    @error_message
  end

  private

  def error(key, names)
    I18n.t(
      "site_settings.discourse_post_event_allowed_custom_fields_#{key}",
      names: names.join(", "),
    )
  end
end
