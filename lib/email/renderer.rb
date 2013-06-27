require_dependency 'email/styles'

module Email
  class Renderer

    def initialize(message, opts=nil)
      @message = message
      @opts = opts || {}
    end

    def text
      @text ||= @message.body.to_s.force_encoding('UTF-8')
    end

    def logo_url
      logo_url = SiteSetting.logo_url
      if logo_url !~ /http(s)?\:\/\//
        logo_url = "#{Discourse.base_url}#{logo_url}"
      end
      logo_url
    end

    def html
      style = Email::Styles.new(PrettyText.cook(text))
      style.format_basic

      if @opts[:html_template]
        style.format_html

        ActionView::Base.new(Rails.configuration.paths["app/views"]).render(
          template: 'email/template',
          format: :html,
          locals: { html_body: style.to_html, logo_url: logo_url }
        )
      else
        style.to_html
      end
    end

  end
end