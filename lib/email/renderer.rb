# frozen_string_literal: true

module Email
  class Renderer
    LOCALE_HEADER = "X-Discourse-Email-Locale"
    THEME_HEADER = "X-Discourse-Email-Theme"

    def initialize(message, opts = nil)
      @message = message
      built_message = @message.respond_to?(:message) ? @message.message : @message
      @theme_renderer = built_message.instance_variable_get(:@discourse_email_theme_renderer)
      @opts = (opts || {}).dup
      @opts[:locale] = @message.header[LOCALE_HEADER]&.value.presence || @opts[:locale] ||
        I18n.locale
      if theme_id = @message.header[THEME_HEADER]&.value.presence
        @opts[:theme_id] = theme_id.to_i
        @opts[:preview_theme] = true
      end
    end

    def text
      return @text if defined?(@text)

      @text = theme_renderer.text(original_text)
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
                html_body:
                  PrettyText.cook(
                    CGI.unescapeHTML(original_text),
                    user_id: @opts[:user_id],
                  ).html_safe,
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

    def original_text
      @original_text ||= (+(@message.text_part || @message).body.to_s).force_encoding("UTF-8")
    end

    def theme_renderer
      @theme_renderer ||=
        Email::ThemeRenderer.new(
          unsubscribe_url: unsubscribe_url,
          locale: @opts[:locale],
          theme_id: @opts[:theme_id],
          preview_theme: @opts[:preview_theme],
        )
    end

    def unsubscribe_url
      header = @message.header["List-Unsubscribe"]
      header = header.last if header.is_a?(Array)
      header&.value&.match(/<([^>]+)>/)&.captures&.first
    end
  end
end
