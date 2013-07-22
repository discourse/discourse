require_dependency 'email/renderer'

class Admin::EmailController < Admin::AdminController

  def index
    render_json_dump({
      delivery_method: delivery_method,
      settings: delivery_settings
    })
  end

  def test
    params.require(:email_address)
    Jobs.enqueue(:test_email, to_address: params[:email_address])
    render nothing: true
  end

  def logs
    @email_logs = EmailLog.limit(50).includes(:user).order('created_at desc').to_a
    render_serialized(@email_logs, EmailLogSerializer)
  end

  def preview_digest
    params.require(:last_seen_at)
    renderer = Email::Renderer.new(UserNotifications.digest(current_user, since: params[:last_seen_at]), html_template: true)
    render json: MultiJson.dump(html_content: renderer.html, text_content: renderer.text)
  end

  private

  def delivery_settings
    action_mailer_settings
      .reject { |k, v| k == :password }
      .map    { |k, v| { name: k, value: v }}
  end

  def delivery_method
    ActionMailer::Base.delivery_method
  end

  def action_mailer_settings
    ActionMailer::Base.public_send "#{delivery_method}_settings"
  end
end
