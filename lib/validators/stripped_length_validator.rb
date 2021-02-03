# frozen_string_literal: true

class StrippedLengthValidator < ActiveModel::EachValidator
  def self.validate(record, attribute, value, range)
    if !value.nil?
      html_comments_regexp = /<!--(.*?)-->/
      stripped_length = value.gsub(html_comments_regexp, '')
      stripped_length = stripped_length.strip.length

      record.errors.add attribute, (I18n.t('errors.messages.too_short', count: range.begin)) unless
          stripped_length >= range.begin
      record.errors.add attribute, (I18n.t('errors.messages.too_long_validation', max: range.end, length: stripped_length)) unless
          stripped_length <= range.end
    else
      record.errors.add attribute, (I18n.t('errors.messages.blank'))
    end
  end

  def validate_each(record, attribute, value)
    # the `in` parameter might be a lambda when the range is dynamic
    range = options[:in].lambda? ? options[:in].call : options[:in]
    self.class.validate(record, attribute, value, range)
  end
end
