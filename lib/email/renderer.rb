# frozen_string_literal: true

module Email
  class Renderer
    def initialize(message, opts = nil)
      @message = message
      built_message = @message.respond_to?(:message) ? @message.message : @message
      @theme_renderer = built_message.instance_variable_get(:@discourse_email_theme_renderer)
      # HTML built outside the email layout has no theme branding, so the text part gets none either.
      @html_uses_layout = @message.html_part.nil? || @theme_renderer.present?
      @opts = opts || {}
    end

    def text
      return @text if defined?(@text)

      @text = @html_uses_layout ? theme_renderer.text(original_text) : original_text
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
          locale: @opts[:locale] || I18n.locale,
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
