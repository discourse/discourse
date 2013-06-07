require_dependency 'email_styles'

class EmailRenderer

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
    cooked = PrettyText.cook(text, environment: 'email')

    if @opts[:html_template]
      ActionView::Base.new(Rails.configuration.paths["app/views"]).render(
        template: 'email/template',
        format: :html,
        locals: { html_body: EmailStyles.new(cooked).format, logo_url: logo_url }
      )
    else
      cooked
    end
  end

end
