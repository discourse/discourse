class UploadUrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.present?
      uri = URI.parse(value) rescue nil

      unless uri && Upload.exists?(url: value)
        record.errors[attribute] << (options[:message] || I18n.t('errors.messages.invalid'))
      end
    end
  end
end
