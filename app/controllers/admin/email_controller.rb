require_dependency 'email/renderer'

class Admin::EmailController < Admin::AdminController

  def index
    data = { delivery_method: delivery_method, settings: delivery_settings }
    render_json_dump(data)
  end

  def test
    params.require(:email_address)
    begin
      Jobs::TestEmail.new.execute(to_address: params[:email_address])
      render nothing: true
    rescue => e
      render json: {errors: [e.message]}, status: 422
    end
  end

  def all
    email_logs = filter_email_logs(EmailLog.all, params)
    render_serialized(email_logs, EmailLogSerializer)
  end

  def sent
    email_logs = filter_email_logs(EmailLog.sent, params)
    render_serialized(email_logs, EmailLogSerializer)
  end

  def skipped
    email_logs = filter_email_logs(EmailLog.skipped, params)
    render_serialized(email_logs, EmailLogSerializer)
  end

  def preview_digest
    params.require(:last_seen_at)
    renderer = Email::Renderer.new(UserNotifications.digest(current_user, since: params[:last_seen_at]))
    render json: MultiJson.dump(html_content: renderer.html, text_content: renderer.text)
  end

  def handle_mail
    params.require(:email)
    Email::Receiver.new(params[:email]).process
    render text: "email was processed"
  end

  private

  def filter_email_logs(email_logs, params)
    email_logs = email_logs.limit(50).includes(:user).order("email_logs.created_at desc").references(:user)
    email_logs = email_logs.where("users.username LIKE ?", "%#{params[:user]}%") if params[:user].present?
    email_logs = email_logs.where("email_logs.to_address LIKE ?", "%#{params[:address]}%") if params[:address].present?
    email_logs = email_logs.where("email_logs.email_type LIKE ?", "%#{params[:type]}%") if params[:type].present?
    email_logs = email_logs.where("email_logs.reply_key LIKE ?", "%#{params[:reply_key]}%") if params[:reply_key].present?
    email_logs = email_logs.where("email_logs.skipped_reason LIKE ?", "%#{params[:skipped_reason]}%") if params[:skipped_reason].present?
    email_logs.to_a
  end

  def delivery_settings
    action_mailer_settings
      .reject { |k, _| k == :password }
      .map    { |k, v| { name: k, value: v }}
  end

  def delivery_method
    ActionMailer::Base.delivery_method
  end

  def action_mailer_settings
    ActionMailer::Base.public_send "#{delivery_method}_settings"
  end
end
