# frozen_string_literal: true

module HasSanitizableFields
  extend ActiveSupport::Concern

  def sanitize_field(field, additional_attributes: [])
    if field
      sanitizer = Rails::Html::SafeListSanitizer.new
      allowed_attributes = Rails::Html::SafeListSanitizer.allowed_attributes

      if additional_attributes.present?
        allowed_attributes = allowed_attributes.merge(additional_attributes)
      end

      field = CGI.unescape_html(
        CGI.unescape(
          sanitizer.sanitize(field, attributes: allowed_attributes)
        )
      )
    end

    field
  end
end
