class StrippedLengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value.nil?
      stripped_length = value.strip.length
      range = options[:in]
      record.errors.add attribute, (options[:message] || I18n.t('errors.messages.too_short', count: range.begin)) unless
          stripped_length >= range.begin
      record.errors.add attribute, (options[:message] || I18n.t('errors.messages.too_long', count: range.end)) unless
          stripped_length <= range.end
    else
      record.errors.add attribute, (options[:message] || I18n.t('errors.messages.blank'))
    end
  end
end
