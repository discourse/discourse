# Help us build an email
module EmailBuilder

  def build_email(to, email_key, params={})
    params[:site_name] = SiteSetting.title
    params[:base_url] = Discourse.base_url
    params[:user_preferences_url] = "#{Discourse.base_url}/user_preferences"

    body = I18n.t("#{email_key}.text_body_template", params)

    # Are we appending an unsubscribe link?
    if params[:add_unsubscribe_link]
      body << "\n"
      body << I18n.t("unsubscribe_link", params)
      headers 'List-Unsubscribe' => "<#{params[:user_preferences_url]}>"
    end

    mail_args = {
      to: to,
      subject: I18n.t("#{email_key}.subject_template", params),
      body: body
    }
    mail_args[:from] = params[:from] || SiteSetting.notification_email
    mail_args[:charset] = 'UTF-8'
    mail(mail_args)
  end

end
