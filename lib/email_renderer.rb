require_dependency 'email_styles'

class EmailRenderer

  def initialize(message)
    @message = message
  end

  def text
    @text ||= @message.body.to_s.force_encoding('UTF-8')
  end

  def html
    formatted_body = EmailStyles.new(PrettyText.cook(text, environment: 'email')).format

    logo_url = SiteSetting.logo_url
    if logo_url !~ /http(s)?\:\/\//
      logo_url = "#{Discourse.base_url}#{logo_url}"
    end

    ActionView::Base.new(Rails.configuration.paths["app/views"]).render(
      template: 'email/template',
      format: :html,
      locals: { html_body: formatted_body,
                logo_url: logo_url }
    )
  end

end
