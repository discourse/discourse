class UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.present?
      valid =
        begin
          uri = URI.parse(value)
          uri.is_a?(URI::HTTP) && !uri.host.nil? && uri.host.include?(".")
        rescue URI::InvalidURIError => e
          if (e.message =~ /URI must be ascii only/)
            value = URI.encode(value)
            retry
          end

          nil
        end

      unless valid
        record.errors[attribute] << (options[:message] || I18n.t('errors.messages.invalid'))
      end
    end
  end
end
