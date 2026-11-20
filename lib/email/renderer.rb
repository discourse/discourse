# frozen_string_literal: true

module Email
  class Renderer
    def initialize(message, opts = nil)
      @message = message
      @opts = opts || {}
    end

    def text
      @text ||=
        if moderation_guideline?
          Dsa::ModerationGuideline.email_plain_text(raw_body)
        else
          CGI.unescapeHTML(raw_body)
        end
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
                html_body: PrettyText.cook(html_source, user_id: @opts[:user_id]).html_safe,
                email_preview: email_preview,
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

    def raw_body
      (+(@message.text_part || @message).body.to_s).force_encoding("UTF-8")
    end

    def moderation_guideline?
      @message.header[Dsa::ModerationGuideline::EMAIL_HEADER].present?
    end

    def html_source
      moderation_guideline? ? Dsa::ModerationGuideline.email_html_source(raw_body) : text
    end
  end
end
