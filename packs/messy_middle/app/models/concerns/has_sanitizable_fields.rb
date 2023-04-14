# frozen_string_literal: true

module HasSanitizableFields
  extend ActiveSupport::Concern

  def sanitize_field(field, additional_attributes: [])
    if field
      sanitizer = Rails::Html::SafeListSanitizer.new
      allowed_attributes = Rails::Html::SafeListSanitizer.allowed_attributes.dup

      if additional_attributes.present?
        allowed_attributes = allowed_attributes.merge(additional_attributes)
      end

      field = CGI.unescape_html(sanitizer.sanitize(field, attributes: allowed_attributes))
      # Just replace the characters that our translations use for interpolation.
      # Calling CGI.unescape removes characters like '+', which will corrupt the original value.
      field = field.gsub("%7B", "{").gsub("%7D", "}")
    end

    field
  end
end
