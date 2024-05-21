# frozen_string_literal: true

module Email
  class Renderer
    def initialize(message, opts = nil)
      @message = message
      @opts = opts || {}
    end

    def text
      return @text if @text
      @text =
        (+(@message.text_part ? @message.text_part : @message).body.to_s).force_encoding("UTF-8")
      @text = CGI.unescapeHTML(@text)
    end

    def html
      style =
        if @message.html_part
          Email::Styles.new(@message.html_part.body.to_s, @opts)
        else
          unstyled =
            UserNotificationRenderer.render(
              template: "layouts/email_template",
              format: :html,
              locals: {
                html_body: PrettyText.cook(text).html_safe,
              },
            )
          Email::Styles.new(unstyled, @opts)
        end
      Rails.logger.info("xxxxx EmailRenderer apply styles")
      style.format_basic
      style.format_html
      Rails.logger.info("xxxxx EmailRenderer post apply styles")
      begin
        DiscoursePluginRegistry.apply_modifier(:email_renderer_html, style, @message)
      rescue => e
        Rails.logger.info("xxxxx DiscoursePluginRegistry.apply_modifier error: #{e}")
      end
      Rails.logger.info("xxxxx EmailRenderer post apply plugin styles")
      style.to_html
    end
  end
end
