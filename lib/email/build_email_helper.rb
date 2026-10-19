# frozen_string_literal: true

module Email
  module BuildEmailHelper
    def build_email(*builder_args)
      builder = Email::MessageBuilder.new(*builder_args)
      @email_theme_renderer =
        Email::ThemeRenderer.new(
          unsubscribe_url: builder.template_args[:unsubscribe_url],
          locale: builder.template_args[:locale] || I18n.locale,
          theme_id: builder.template_args[:theme_id],
          preview_theme: builder.template_args[:preview_theme],
        )
      headers(builder.header_args)
      headers(
        Email::Renderer::LOCALE_HEADER => (builder.template_args[:locale] || I18n.locale).to_s,
      )
      if builder.template_args[:preview_theme] && builder.template_args[:theme_id].present?
        headers(Email::Renderer::THEME_HEADER => builder.template_args[:theme_id].to_s)
      end
      mail(builder.build_args).tap do |message|
        # Share resolved branding between HTML generation and the later plain-text pass.
        message&.instance_variable_set(:@discourse_email_theme_renderer, @email_theme_renderer)
        if message && h = builder.html_part(theme_renderer: @email_theme_renderer)
          message.html_part = h
        end
      end
    end
  end
end
