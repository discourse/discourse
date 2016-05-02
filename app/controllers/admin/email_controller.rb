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

  def sent
    email_logs = filter_email_logs(EmailLog.sent, params)
    render_serialized(email_logs, EmailLogSerializer)
  end

  def skipped
    email_logs = filter_email_logs(EmailLog.skipped, params)
    render_serialized(email_logs, EmailLogSerializer)
  end

  def bounced
    email_logs = filter_email_logs(EmailLog.bounced, params)
    render_serialized(email_logs, EmailLogSerializer)
  end

  def received
    incoming_emails = filter_incoming_emails(IncomingEmail, params)
    render_serialized(incoming_emails, IncomingEmailSerializer)
  end

  def rejected
    incoming_emails = filter_incoming_emails(IncomingEmail.errored, params)
    render_serialized(incoming_emails, IncomingEmailSerializer)
  end

  def preview_digest
    params.require(:last_seen_at)
    params.require(:username)
    user = User.find_by_username(params[:username])
    renderer = Email::Renderer.new(UserNotifications.digest(user, since: params[:last_seen_at]))
    render json: MultiJson.dump(html_content: renderer.html, text_content: renderer.text)
  end

  def handle_mail
    params.require(:email)
    Email::Receiver.new(params[:email]).process!
    render text: "email was processed"
  end

  def raw_email
    params.require(:id)
    incoming_email = IncomingEmail.find(params[:id].to_i)
    render json: { raw_email: incoming_email.raw }
  end

  def incoming
    params.require(:id)
    incoming_email = IncomingEmail.find(params[:id].to_i)
    serializer = IncomingEmailDetailsSerializer.new(incoming_email, root: false)
    render_json_dump(serializer)
  end

  private

  def filter_email_logs(email_logs, params)
    email_logs = email_logs.includes(:user, { post: :topic })
                           .references(:user)
                           .order(created_at: :desc)
                           .offset(params[:offset] || 0)
                           .limit(50)

    email_logs = email_logs.where("users.username ILIKE ?", "%#{params[:user]}%") if params[:user].present?
    email_logs = email_logs.where("email_logs.to_address ILIKE ?", "%#{params[:address]}%") if params[:address].present?
    email_logs = email_logs.where("email_logs.email_type ILIKE ?", "%#{params[:type]}%") if params[:type].present?
    email_logs = email_logs.where("email_logs.reply_key ILIKE ?", "%#{params[:reply_key]}%") if params[:reply_key].present?
    email_logs = email_logs.where("email_logs.skipped_reason ILIKE ?", "%#{params[:skipped_reason]}%") if params[:skipped_reason].present?

    email_logs
  end

  def filter_incoming_emails(incoming_emails, params)
    incoming_emails = incoming_emails.includes(:user, { post: :topic })
                                     .order(created_at: :desc)
                                     .offset(params[:offset] || 0)
                                     .limit(50)

    incoming_emails = incoming_emails.where("from_address ILIKE ?", "%#{params[:from]}%") if params[:from].present?
    incoming_emails = incoming_emails.where("to_addresses ILIKE ? OR cc_addresses ILIKE ?", "%#{params[:to]}%") if params[:to].present?
    incoming_emails = incoming_emails.where("subject ILIKE ?", "%#{params[:subject]}%") if params[:subject].present?
    incoming_emails = incoming_emails.where("error ILIKE ?", "%#{params[:error]}%") if params[:error].present?

    incoming_emails
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
