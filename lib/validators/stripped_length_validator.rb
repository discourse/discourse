# frozen_string_literal: true

class StrippedLengthValidator < ActiveModel::EachValidator
  def self.validate(record, attribute, value, range)
    if value.blank?
      record.errors.add attribute, I18n.t("errors.messages.blank")
    elsif value.length > range.end
      record.errors.add attribute,
                        I18n.t(
                          "errors.messages.too_long_validation",
                          max: range.end,
                          length: value.length,
                        )
    else
      value = get_sanitized_value(value)

      if value.length < range.begin
        record.errors.add attribute, I18n.t("errors.messages.too_short", count: range.begin)
      end
    end
  end

  def validate_each(record, attribute, value)
    # the `in` parameter might be a lambda when the range is dynamic
    range = options[:in].lambda? ? options[:in].call : options[:in]
    self.class.validate(record, attribute, value, range)
  end

  def self.get_sanitized_value(value)
    value = value.dup
    value.gsub!(/<!--(.*?)-->/, "") # strip HTML comments
    value.gsub!(/:\w+(:\w+)?:/, "X") # replace emojis with a single character
    value.gsub!(/\.{2,}/, "…") # replace multiple ... with …
    value.gsub!(/\,{2,}/, ",") # replace multiple ,,, with ,
    value.strip
  end
end
