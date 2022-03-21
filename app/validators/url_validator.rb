# frozen_string_literal: true

class UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.present?
      valid =
        begin
          uri = URI.parse(value)
          uri.is_a?(URI::HTTP) && !uri.host.nil? && uri.host.include?(".")
        rescue URI::Error => e
          if (e.message =~ /URI must be ascii only/)
            value = UrlHelper.encode(value)
            retry
          end

          nil
        end

      unless valid
        record.errors.add(attribute, options[:message] || I18n.t('errors.messages.invalid'))
      end
    end
  end
end
