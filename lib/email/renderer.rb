# frozen_string_literal: true

require_dependency 'email/styles'

module Email
  class Renderer

    def initialize(message, opts = nil)
      @message = message
      @opts = opts || {}
    end

    def text
      return @text if @text
      @text = (+(@message.text_part ? @message.text_part : @message).body.to_s).force_encoding('UTF-8')
      @text = CGI.unescapeHTML(@text)
    end

    def html
      style = if @message.html_part
        Email::Styles.new(@message.html_part.body.to_s, @opts)
      else
        unstyled = UserNotificationRenderer.with_view_paths(
          Rails.configuration.paths["app/views"]
        ).render(
          template: 'layouts/email_template',
          format: :html,
          locals: { html_body: PrettyText.cook(text).html_safe }
        )
        Email::Styles.new(unstyled, @opts)
      end

      style.format_basic
      style.format_html
      style.to_html
    end

  end
end
