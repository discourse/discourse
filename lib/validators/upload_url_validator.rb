class UploadUrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.present?
      uri =
        begin
          URI.parse(value)
        rescue URI::InvalidURIError
        end

      unless uri && Discourse.store.has_been_uploaded?(value)
        record.errors[attribute] << (options[:message] || I18n.t('errors.messages.invalid'))
      end
    end
  end
end
