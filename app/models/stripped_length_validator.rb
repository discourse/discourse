class StrippedLengthValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value.nil?
      stripped_length = value.strip.length
      range = options[:in]
      record.errors.add attribute, (options[:message] || "is too short (minimum is #{range.begin}).") unless
          stripped_length >= range.begin
      record.errors.add attribute, (options[:message] || "is too long (maximum is #{range.end}).") unless
          stripped_length <= range.end
    else
      record.errors.add attribute, (options[:message] || "is required.")
    end
  end
end
