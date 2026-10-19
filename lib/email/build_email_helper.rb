# frozen_string_literal: true

module Email
  module BuildEmailHelper
    def build_email(*builder_args)
      builder = Email::MessageBuilder.new(*builder_args)
      @email_theme_renderer =
        Email::ThemeRenderer.new(
          unsubscribe_url: builder.template_args[:unsubscribe_url],
          locale: builder.template_args[:locale] || I18n.locale,
        )
      headers(builder.header_args) if builder.header_args.present?
      mail(builder.build_args).tap do |message|
        if message && h = builder.html_part
          message.html_part = h
        end
      end
    end
  end
end
