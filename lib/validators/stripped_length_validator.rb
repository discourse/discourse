# frozen_string_literal: true

class StrippedLengthValidator < ActiveModel::EachValidator
  def self.validate(record, attribute, value, range, strip_uploads: false)
    if value.blank? && range.begin > 0
      record.errors.add attribute, I18n.t("errors.messages.blank")
    elsif value.length > range.end
      record.errors.add attribute,
                        I18n.t(
                          "errors.messages.too_long_validation",
                          count: range.end,
                          length: value.length,
                        )
    elsif get_sanitized_value(value, strip_uploads:).length < range.begin
      record.errors.add attribute, I18n.t("errors.messages.too_short", count: range.begin)
    end
  end

  def validate_each(record, attribute, value)
    # the `in` parameter might be a lambda when the range is dynamic
    range = options[:in].lambda? ? options[:in].call : options[:in]
    self.class.validate(record, attribute, value, range)
  end

  def self.get_sanitized_value(value, strip_uploads: false)
    value = value.dup
    value.gsub!(/<!--(.*?)-->/, "") # strip HTML comments
    value.gsub!(/:\w+(:\w+)?:/, "X") # replace emojis with a single character
    value.gsub!(/\.{2,}/, "…") # replace multiple ... with …
    value.gsub!(/\,{2,}/, ",") # replace multiple ,,, with ,
    value.gsub!(/!\[.*\]\(.+\)/, "") if strip_uploads

    value.strip
  end
end
