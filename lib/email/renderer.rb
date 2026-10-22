# frozen_string_literal: true

module Email
  class Renderer
    def initialize(message, opts = nil)
      @message = message
      @opts = opts || {}
    end

    def text
      return @text if defined?(@text)

      @text = theme_renderer.text(raw_text)
    end

    def html
      email_preview = @message.header["X-Discourse-Email-Preview"]&.value
      style =
        if @message.html_part
          Email::Styles.new(@message.html_part.body.to_s, @opts)
        else
          unstyled =
            UserNotificationRenderer.render(
              template: "layouts/email_template",
              format: :html,
              locals: {
                html_body: PrettyText.cook(raw_text, user_id: @opts[:user_id]).html_safe,
                email_preview: email_preview,
                email_theme_renderer: theme_renderer,
              },
            )
          Email::Styles.new(unstyled, @opts)
        end

      style.format_basic
      style.format_html
      DiscoursePluginRegistry.apply_modifier(:email_renderer_html, style, @message)
      style.to_html
    end

    private

    def raw_text
      return @raw_text if defined?(@raw_text)

      @raw_text =
        (+(@message.text_part ? @message.text_part : @message).body.to_s).force_encoding("UTF-8")
      @raw_text = CGI.unescapeHTML(@raw_text)
    end

    def theme_renderer
      @theme_renderer ||=
        Email::ThemeRenderer.new(
          unsubscribe_url: unsubscribe_url,
          locale: @opts[:locale] || I18n.locale,
        )
    end

    def unsubscribe_url
      header = @message.header["List-Unsubscribe"]
      header = header.last if header.is_a?(Array)
      header&.value&.match(/<([^>]+)>/)&.captures&.first
    end
  end
end
