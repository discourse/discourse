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
      render body: nil
    rescue => e
      render json: { errors: [e.message] }, status: 422
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

  def send_digest
    params.require(:last_seen_at)
    params.require(:username)
    params.require(:email)
    user = User.find_by_username(params[:username])
    message, skip_reason = UserNotifications.send(:digest, user, since: params[:last_seen_at])
    if message
      message.to = params[:email]
      begin
        Email::Sender.new(message, :digest).send
        render json: success_json
      rescue => e
        render json: { errors: [e.message] }, status: 422
      end
    else
      render json: { errors: skip_reason }
    end
  end

  def smtp_should_reject
    params.require(:from)
    params.require(:to)
    # These strings aren't localized; they are sent to an anonymous SMTP user.
    if !User.with_email(Email.downcase(params[:from])).exists? && !SiteSetting.enable_staged_users
      render json: { reject: true, reason: "Mail from your address is not accepted. Do you have an account here?" }
    elsif Email::Receiver.check_address(Email.downcase(params[:to])).nil?
      render json: { reject: true, reason: "Mail to this address is not accepted. Check the address and try to send again?" }
    else
      render json: { reject: false }
    end
  end

  def handle_mail
    params.require(:email)
    retry_count = 0

    begin
      Jobs.enqueue(:process_email, mail: params[:email], retry_on_rate_limit: true)
    rescue JSON::GeneratorError => e
      if retry_count == 0
        params[:email] = params[:email].force_encoding('iso-8859-1').encode("UTF-8")
        retry_count += 1
        retry
      else
        raise e
      end
    end

    render plain: "email has been received and is queued for processing"
  end

  def raw_email
    params.require(:id)
    incoming_email = IncomingEmail.find(params[:id].to_i)
    text, html = Email.extract_parts(incoming_email.raw)
    render json: { raw_email: incoming_email.raw, text_part: text, html_part: html }
  end

  def incoming
    params.require(:id)
    incoming_email = IncomingEmail.find(params[:id].to_i)
    serializer = IncomingEmailDetailsSerializer.new(incoming_email, root: false)
    render_json_dump(serializer)
  end

  def incoming_from_bounced
    params.require(:id)

    begin
      bounced = EmailLog.find_by(id: params[:id].to_i)
      raise Discourse::InvalidParameters if bounced.nil?

      email_local_part, email_domain = SiteSetting.notification_email.split('@')
      bounced_to_address = "#{email_local_part}+verp-#{bounced.bounce_key}@#{email_domain}"

      incoming_email = IncomingEmail.find_by(to_addresses: bounced_to_address)
      raise Discourse::NotFound if incoming_email.nil?

      serializer = IncomingEmailDetailsSerializer.new(incoming_email, root: false)
      render_json_dump(serializer)
    rescue => e
      render json: { errors: [e.message] }, status: 404
    end
  end

  private

  def filter_email_logs(email_logs, params)
    email_logs = email_logs.includes(:user, post: :topic)
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
    incoming_emails = incoming_emails.includes(:user, post: :topic)
      .order(created_at: :desc)
      .offset(params[:offset] || 0)
      .limit(50)

    incoming_emails = incoming_emails.where("from_address ILIKE ?", "%#{params[:from]}%") if params[:from].present?
    incoming_emails = incoming_emails.where("to_addresses ILIKE :to OR cc_addresses ILIKE :to", to: "%#{params[:to]}%") if params[:to].present?
    incoming_emails = incoming_emails.where("subject ILIKE ?", "%#{params[:subject]}%") if params[:subject].present?
    incoming_emails = incoming_emails.where("error ILIKE ?", "%#{params[:error]}%") if params[:error].present?

    incoming_emails
  end

  def delivery_settings
    action_mailer_settings
      .reject { |k, _| k == :password }
      .map    { |k, v| { name: k, value: v } }
  end

  def delivery_method
    ActionMailer::Base.delivery_method
  end

  def action_mailer_settings
    ActionMailer::Base.public_send "#{delivery_method}_settings"
  end
end
